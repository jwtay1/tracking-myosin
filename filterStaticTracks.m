clearvars
clc

dataDir = 'C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\Processed\20240607';

files = dir(fullfile(dataDir, '*.mat'));

outputDir = 'C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\Processed\20240607_filtered';

if ~exist(outputDir, 'dir')
    mkdir(outputDir)
end

for iFile = 1:numel(files)

    load(fullfile(dataDir, files(iFile).name));
    
    % %Remove stationary particles
    % figure;
    % hold on
    for ii = 1:L.NumTracks

        ct = getTrack(L, ii);

        if numel(ct.Frames) < 10
            %Filter tracks < 5 frame slong
            continue;
        end

        %Compute the displacement at each frame
        %displacementStep = [0; sqrt(sum((diff(ct.Centroid, 1)).^2, 2))];

        % totalDisplacement = sum(displacementStep);
        displacement = sqrt(sum((ct.Centroid(1, :) - ct.Centroid(end, :)).^2));

        if displacement > 5
            if ~exist('filteredTracks', 'var')
                filteredTracks = ct;
            else
                filteredTracks = [filteredTracks; ct];
            end
        end
        % 
        % 
        % %Classify if particle is moving or not
        % isMoving = displacementStep > 1.75;
        % 
        % %Classify if particle is moving or not
        % if nnz(isMoving) >= 3 %(0.1 * numel(ct.Frames))
        %     % classification = 'moving';
        %     % plot(ct.Centroid(:, 1), ct.Centroid(:, 2), 'g')
        % 
        %     if ~exist('filteredTracks', 'var')
        %         filteredTracks = ct;
        %     else
        %         filteredTracks = [filteredTracks; ct];
        %     end
        % 
        % else
        %     % classification = 'immobile';
        %     % plot(ct.Centroid(:, 1), ct.Centroid(:, 2), 'r')
        % end

    end
    % hold off
    % %% Try to combine tracks
    % 
    % nFrames = numel(imfinfo(file));
    % 
    % for ii = 1:L.NumTracks
    % 
    %     ct = getTrack(L, ii);
    % 
    %     if ct.Frames(end) ~= nFrames
    % 
    %         for jj = ii:L.NumTracks
    % 
    %             %Find a nearby track that starts on a similar frame
    % 
    % 
    % 
    % 
    % 
    % 
    %         end
    % 
    % 
    % 
    % 
    % 
    % 
    % 
    %     end
    % 
    % end





    %%
    if ~exist("filteredTracks", 'var')
        continue
    end


    resizeFactor = 8;

    %Make a video showing only moving particles
    [~, fn] = fileparts(files(iFile).name);
    vid = VideoWriter(fullfile(outputDir, [fn, '_filtered.avi']));
    vid.FrameRate = 5;
    open(vid)

    nFrames = numel(imfinfo(file));

    for iFrame = 1:nFrames

        I = imread(file, iFrame);
        I = I(cropRange(1):cropRange(2), cropRange(3):cropRange(4),:);
        I = imresize(I, resizeFactor, 'nearest');
        % imshow(I, [])

        for iTrack = 1:numel(filteredTracks)

            inFrame = filteredTracks(iTrack).Frames == iFrame;

            frameIdx = find(inFrame, 1, 'first');

            if ~isempty(frameIdx)

                I = insertShape(I, 'filled-circle', ...
                    [filteredTracks(iTrack).Centroid(frameIdx, 1) * resizeFactor, filteredTracks(iTrack).Centroid(frameIdx, 2) * resizeFactor, 4], ...
                    'ShapeColor', 'magenta');

                if frameIdx > 1
                    I = insertShape(I, 'line', filteredTracks(iTrack).Centroid(1:frameIdx, :) * resizeFactor, ...
                        'ShapeColor', 'magenta');
                end
            end

        end

        writeVideo(vid, I);

    end
    close(vid)

    save(fullfile(outputDir, [fn, '_filtered.mat']), 'filteredTracks')
    clearvars filteredTracks

end
