clearvars
clc

load('test.mat');

%Process data to remove erroneous tracks
for iTrack = 1:L.NumTracks

    ct = getTrack(L, iTrack);

    numFrames = numel(ct.Frames);

    if numFrames <= 2
        continue

    else

        ct.NumFrames = numFrames;

        %Classify if moving or stationary - we might be able to do on track
        %length
        ct.Displacement = sqrt(sum((ct.Centroid - ct.Centroid(1, :)).^2, 2));

        if max(ct.Displacement) > 10

             ct.type = 'moving';

        else
            
            ct.type = 'stationary';

        end

        % if numFrames > 10
        %     ct.type = 'stationary';
        % else
        %     ct.type = 'moving';
        % end

        if ~exist('storeData', 'var')
            storeData = ct;
            
        else
            idx = numel(storeData) + 1;            
            storeData(idx) = ct;
            
        end
     
    end
end

%% Plot
file = 'D:\Documents\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Massimo\Plate2 Delta38_5pMoles009_substack.tif';

startFrame = min(cellfun(@min, {storeData.Frames}));
lastFrame = max(cellfun(@max, {storeData.Frames}));

vid = VideoWriter('processed.avi');
open(vid)

for iT = startFrame:lastFrame

    I = imread(file, iT);
    I = imresize(I, 2);

    for iTrack = 1:numel(storeData)

        idx = find(storeData(iTrack).Frames == iT);

        if ~isempty(idx)

            I = double(I);
            I = (I - min(I, [], 'all'))/(max(I, [], 'all') - min(I, [], 'all'));

            if strcmpi(storeData(iTrack).type, 'stationary')
                color = 'r';
            else
                color = 'y';
            end

            I = insertShape(I, 'filled-circle', ...
                [storeData(iTrack).Centroid(idx, :), 2], ...
                'Color', color);

        end
    end

    writeVideo(vid, I)

end

close(vid)

