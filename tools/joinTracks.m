function joinTracks(matfilePath, track1, track2)

load(matfilePath);

tracks = L.tracks;

for xx = 1:numel(track1)

    tracks = joinTrack(tracks, track1(xx), track2(xx), 'true');
end


[~, fn] = fileparts(matfilePath);

save([fn, '_edited.mat'], 'tracks');

%Remake the movie
nFrames = numel(imfinfo(file));

expandSize = 6;

vid = VideoWriter([fn, '_edited.avi']);
vid.FrameRate = 5;
open(vid)

for iT = 1:nFrames

    %--Generate output movies and images--%
    %Read image
    Irgb = imread(file, iT);

    %Crop the image
    if iT == 1
        [Irgb, cropRange] = FreeMyosinTracker.cropImage(Irgb);
    else
        Irgb = FreeMyosinTracker.cropImage(Irgb, cropRange);
    end

    Iout = imresize(Irgb, expandSize);

    for ii = 1:numel(tracks)

        try
            ct = getTrack(tracks, ii);
        catch
            continue
        end

        if ~ismember(iT, ct.Frames)
            continue
        else
            frameIdx = find(ct.Frames == iT, 1, 'first');

            ct.Centroid = ct.Centroid * expandSize;

            Iout = insertShape(Iout, 'filled-circle', ...
                [ct.Centroid(frameIdx, 1), ct.Centroid(frameIdx, 2), 2], ...
                'ShapeColor', 'white');

            Iout = insertText(Iout, [ct.Centroid(frameIdx, 1), ct.Centroid(frameIdx, 2)], ...
                int2str(ii), 'BoxOpacity', 0, 'TextColor', 'yellow', ...
                'AnchorPoint', 'CenterTop');

            if frameIdx > 1

                Iout = insertShape(Iout, 'line', ct.Centroid(1:frameIdx, :), ...
                    'ShapeColor', 'magenta');

            end
        end

    end

    writeVideo(vid, Iout);
end

close(vid)