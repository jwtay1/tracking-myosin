%Join tracks

matFile = 'C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\Processed\20240607_filtered\RGB_WT_plate1_labelled_2_25_50pm007_A_filtered.mat';
load (matFile)

file = 'C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\data\selected\RGB_WT_plate1_labelled_2_25_50pm007_A.tif';
outputDir = 'C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\Processed\20240607_filtered';

for iF = 1:numel(filteredTracks)

    disp(['Track = ', int2str(iF)])
    disp(filteredTracks(iF).Frames)

end

%%
trackToJoin = [1 5];

for ii = 1:size(trackToJoin, 1)

    fields = fieldnames(filteredTracks);

    for iField = 1:numel(fields)

        if size(filteredTracks(trackToJoin(ii, 1)).(fields{iField}), 1) == 1
            filteredTracks(trackToJoin(ii, 1)).(fields{iField}) = ...
                [filteredTracks(trackToJoin(ii, 1)).(fields{iField}), ...
                filteredTracks(trackToJoin(ii, 2)).(fields{iField})];


        else

        filteredTracks(trackToJoin(ii, 1)).(fields{iField}) = ...
            cat(1, filteredTracks(trackToJoin(ii, 1)).(fields{iField}), ...
            filteredTracks(trackToJoin(ii, 2)).(fields{iField}));
        end
    end

end

for ii = 1:size(trackToJoin, 1)

    filteredTracks(trackToJoin(ii, 2)) = [];

end

%%
   
    resizeFactor = 8;

    %Make a video showing only moving particles
    [~, fn] = fileparts(file);
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