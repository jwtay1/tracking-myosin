classdef FreeMyosinTracker

    properties

    end

    methods

        function processVideos(obj, folder, outputFolder, varargin)

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
                L.MaxTrackAge = 1;
                L.LinkScoreRange = [0 6];

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
                    Ispot = double(Irgb(:, :, 2));

                    %Expand image to make it easier to identify particles
                    mask = FreeMyosinTracker.identifySpots(Ispot);
                    
                    if ~any(mask, 'all')
                        break;
                    end

                    %Segment filaments
                    Ifil = Irgb(:, :, 1);

                    Ifil(Ifil == 0) = NaN;
                    th = graythresh(Ifil);

                    filamentMask = Ifil > (th * 255);
                    filamentMask = imopen(filamentMask, strel('disk', 1));

                    %Measure distance to closest filament pixel
                    dist = bwdist(filamentMask);

                    %Measure amount of red under the particle
                    data = regionprops(mask, Ifil, 'Centroid', 'MeanIntensity');

                    for ii = 1:numel(data)
                        loc = round(data(ii).Centroid);

                        data(ii).Distance = dist(loc(2), loc(1));
                    end

                    %Track particles
                    L = assignToTrack(L, iT, data);

                    %--Generate output movies and images--%
                    expandSize = 6;

                    Iout = showoverlay(imresize(Irgb, expandSize),...
                        imresize(mask, expandSize, 'nearest'), 'Opacity', 30);
                    Iout = showoverlay(Iout, ...
                        bwperim(imresize(filamentMask, expandSize, 'nearest')), 'color', [1 1 0]);

                    IoutL = Iout;
                    IoutR = Iout;

                    for ii = L.activeTrackIDs

                        ct = getTrack(L, ii);

                        ct.Centroid = ct.Centroid * expandSize;

                        IoutL = insertShape(IoutL, 'filled-circle', ...
                            [ct.Centroid(end, 1), ct.Centroid(end, 2), 2], ...
                            'ShapeColor', 'white');

                        if numel(ct.Frames) > 1
                            
                            IoutL = insertShape(IoutL, 'line', ct.Centroid, ...
                                'ShapeColor', 'magenta');

                        end

                        IoutR = insertText(IoutR, [ct.Centroid(end, 1), ct.Centroid(end, 2)], ...
                            int2str(ii), 'BoxOpacity', 0, 'TextColor', 'blue', ...
                            'AnchorPoint', 'Center');

                    end

                    Iout = [IoutL, zeros(size(IoutL, 1), 3, 3, 'uint8'), IoutR];

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

                Ispot = Irgb(:, :, 2);

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

            %Expand image to make it easier to identify particles
            I = imresize(I, 2, 'nearest');
            
            dg1 = imgaussfilt(I, ip.Results.spotRange(1));
            dg2 = imgaussfilt(I, ip.Results.spotRange(2));

            dog = dg1 - dg2;

            mask = dog > 20;
            mask = bwareaopen(mask, 2);

            mask = imresize(mask, 0.5, 'nearest');

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