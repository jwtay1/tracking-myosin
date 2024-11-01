classdef FreeMyosinTracker
    %FREEMYOSINTRACKER  Track myosin molecules in videos
    %
    %  F = FREEMYOSINTRACKER creates a new object that can be used to track
    %  myosin molecules in timelapse fluorescence datasets. The datasets
    %  are assumed to consist of two channel images: (1) fluorescently
    %  labeled myosin spots and (2) fluroescently labeled actin filaments.
    %
    %  See also: FreeMyosinTracker/processVideos
   

    properties

        spotChannel = 1;
        filamentChannel = 2;

    end

    methods

        function processVideos(obj, folder, outputFolder, varargin)
            %PROCESSVIDEOS  Process videos
            %
            %  PROCESSVIDEOS(F, INPUT_DIR, OUTPUT_DIR) processes all
            %  nd2-files in the INPUT_DIR. The following output files will
            %  be written to the OUTPUT_DIR:
            %    * An AVI-file, upscaled by 6x, showing tracked particle
            %      IDs and trajectories
            %    * A MAT-File containing raw data
            %    * A TIFF-file containing particle masks
            %   

            %Parse inputs
            if ~exist(outputFolder, 'dir')
                mkdir(outputFolder)
            end

            files = dir(fullfile(folder, '*.tif'));

            for iFile = 1:numel(files)

                file = fullfile(files(iFile).folder, files(iFile).name);

                %Number of frames
                nFrames = numel(imfinfo(file));

                %Set up linking object
                L = LAPLinker;
                L.MaxTrackAge = 2;
                L.LinkScoreRange = [0 8];

                [~, fn] = fileparts(files(iFile).name);

                vid = VideoWriter(fullfile(outputFolder, [fn, '.avi']));
                vid.FrameRate = 5;
                open(vid)

                for iT = 1:nFrames

                    %Read image
                    Irgb = imread(file, iT);
                    
                    %Crop the image
                    if iT == 1
                        [Irgb, cropRange] = FreeMyosinTracker.cropImage(Irgb);
                    else
                        Irgb = FreeMyosinTracker.cropImage(Irgb, cropRange);
                    end
                    
                    %Find myosin particles
                    Ispot = double(Irgb(:, :, obj.spotChannel));

                    %Expand image to make it easier to identify particles
                    mask = FreeMyosinTracker.identifySpots(Ispot);
                    
                    if ~any(mask, 'all')
                        break;
                    end

                    %Segment filaments
                    try
                    Ifil = Irgb(:, :, obj.filamentChannel);
                    catch
                        keyboard
                    end

                    Ifil(Ifil == 0) = NaN;
                    th = graythresh(Ifil);

                    filamentMask = Ifil > (th * 255);
                    filamentMask = imopen(filamentMask, strel('disk', 1));

                    % %Measure distance to closest filament pixel
                    % dist = bwdist(filamentMask);

                    %Measure amount of red under the particle
                    data = regionprops(mask, Ifil, 'Centroid', 'MeanIntensity');

                    %Filter out dim particles
                    meanInts = [data.MeanIntensity];

                    thInt = prctile(Ispot(:), 90);
                    data(meanInts <= thInt) = [];

                    % for ii = 1:numel(data)
                    %     loc = round(data(ii).Centroid);
                    % 
                    %     data(ii).Distance = dist(loc(2), loc(1));
                    % end

                    %Track particles
                    try
                        L = assignToTrack(L, iT, data);
                    catch
                        keyboard
                    end

                    %--Generate output movies and images--%
                    expandSize = 6;

                    Iout = imresize(Irgb, expandSize);

                    % IoutL = Iout;
                    % IoutR = Iout;

                    for ii = L.activeTrackIDs

                        ct = getTrack(L, ii);

                        ct.Centroid = ct.Centroid * expandSize;

                        Iout = insertShape(Iout, 'filled-circle', ...
                            [ct.Centroid(end, 1), ct.Centroid(end, 2), 2], ...
                            'ShapeColor', 'white');

                        Iout = insertText(Iout, [ct.Centroid(end, 1), ct.Centroid(end, 2)], ...
                            int2str(ii), 'BoxOpacity', 0, 'TextColor', 'yellow', ...
                            'AnchorPoint', 'CenterTop');

                        if numel(ct.Frames) > 1
                            try
                            Iout = insertShape(Iout, 'line', ct.Centroid, ...
                                'ShapeColor', 'magenta');
                            catch
                                continue
                            end
                        end                      

                    end

                    %Iout = IoutL;

                    % Iout = [IoutL, zeros(size(IoutL, 1), 3, 3, 'uint8'), IoutR];

                    % keyboard
                    writeVideo(vid, Iout);

                    if iT == 1

                        imwrite(filamentMask, fullfile(outputFolder, [fn, '.tif']), 'Compression', 'none')

                    else

                        imwrite(filamentMask, fullfile(outputFolder, [fn, '.tif']), 'Compression', 'none', ...
                            'writeMode', 'append')

                    end

                    

                end

                close(vid)

                save(fullfile(outputFolder, [fn, '.mat']), 'L', 'file', 'cropRange')

            end


        end
    
        function segmentSpots(obj, file, outputDir)
            %SEGMENTSPOTS  Segment spots in an image
            %
            %  SEGMENTSPOTS(FILE, DIR) segments spots in an image,
            %  writing the results to an output file in DIR.

            % if ~exist('file', 'var')
            %
            %     file = uigetfile
            %
            % end

            if ~exist(outputDir, 'dir')
                mkdir(outputDir);
            end
        

            %Number of frames
            nFrames = numel(imfinfo(file));

            [~, fn] = fileparts(file);

            for iT = 1:nFrames

                %Read image
                Irgb = imread(file, iT);

                Ispot = Irgb(:, :, obj.spotChannel);

                mask = FreeMyosinTracker.identifySpots(Ispot);

                if iT == 1

                    imwrite(mask, fullfile(outputDir, [fn, '_spotMask.tif']), 'Compression', 'none')

                else

                    imwrite(mask, fullfile(outputDir, [fn, '_spotMask.tif']), 'Compression', 'none', ...
                        'writeMode', 'append')

                end

            end



        end
    end


    methods (Static)

        function [Icrop, cropRange] = cropImage(Iin, varargin)
            %CROPIMAGE  Auto-crops image to data
            %
            %  C = CROPIMAGE(I) returns the cropped image C, where C is the
            %  region that contains data in I.


            if isempty(varargin)

                if size(Iin, 3) > 1
                    I = Iin(:, :, 1);
                else
                    I = Iin;
                end

                hasData = I > 0;
                row = any(hasData, 2);
                rowRange = [find(row, 1, 'first'), find(row, 1, 'last')];
                col = any(hasData, 1);
                colRange = [find(col, 1, 'first'), find(col, 1, 'last')];

                cropRange = [rowRange(1), rowRange(2), colRange(1), colRange(2)];
            else
                cropRange = varargin{1};
            end

            Icrop = Iin(cropRange(1):cropRange(2), cropRange(3):cropRange(4), :);            

        end

        function mask = identifySpots(I, varargin)
            %IDENTIFYSPOTS  Segment spots using difference of Gaussians
            %
            %  M = IDENTIFYSPOTS(I) creates a mask M of spots using the
            %  difference of Gaussians filter.

            ip = inputParser;
            addParameter(ip, 'spotRange', [3 6]);
            parse(ip, varargin{:})

            I = medfilt2(I, [3 3]);

            %Expand image to make it easier to identify particles
            I = imresize(I, 4);
            
            dg1 = imgaussfilt(I, ip.Results.spotRange(1));
            dg2 = imgaussfilt(I, ip.Results.spotRange(2));

            dog = dg1 - dg2;

            mask = dog > 10;
            mask = bwareaopen(mask, 2);

            dd = -bwdist(~mask);
            dd(~mask) = -Inf;
            dd = imhmin(dd, 0.1);

            L = watershed(dd);

            mask(L == 0) = false;
            mask = bwareaopen(mask, 3);

            mask = bwmorph(mask, 'hbreak');
            %mask = bwmorph(mask, 'shrink', 1);

            mask = imresize(mask, 0.25, 'nearest');

            % imshow(mask, 'InitialMagnification', 400)
     

        end

        function spotCenters = fitSpots(mask)
            %FITSPOTS  Identify spot position by fitting to 2D Gaussian

            

            spotsMarked = bwmorph(mask, 'shrink', 'Inf');

            [spotsRow, spotsCol] = find(spotsMarked);

            for iSpot = 1:numel(spotsRow)

                cropRowStart = spotsRow(iSpot) - 10;
                if cropRowStart < 1
                    cropRowStart = 1;
                end

                cropRowEnd = spotsRow(iSpot) + 10;
                if cropRowEnd > size(I, 1)
                    cropRowEnd = size(I, 1);
                end

                cropRow = cropRowStart:cropRowEnd;

                cropColStart = spotsCol(iSpot) - 10;
                if cropColStart < 1
                    cropColStart = 1;
                end

                cropColEnd = spotsCol(iSpot) + 10;
                if cropColEnd > size(I, 2)
                    cropColEnd = size(I, 2);
                end

                cropCol = cropColStart:cropColEnd;

                %Crop the image
                imgCrop = double(I(cropRow, cropCol));

                %Fit Gaussian
                [xx, yy] = meshgrid(cropCol, cropRow);

                fitted = lsqcurvefit(@gaussmodel, ...
                    [max(max(imgCrop(:))), median(cropCol), median(cropRow), 5, min(min(imgCrop(:)))], ...
                    cat(3, xx, yy), imgCrop);

                plot3(xx, yy, imgCrop, 'o')
                hold on
                surf(xx, yy, gaussmodel(fitted, cat(3, xx, yy)))
                hold off
                pause

            end

        end
            
        function y = gaussmodel(x, xdata)

            A = x(1);
            xOffset = x(2);
            yOffset = x(3);

            sigma = x(4);
            zOffset = x(5);

            y = A .* exp( - ((xdata(:, :, 1) - xOffset).^2 + (xdata(:, :, 2) - yOffset).^2)/(2 * sigma^2)) - zOffset;

        end



    end

end