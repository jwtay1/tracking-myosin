function joinTracks(matfilePath, tracksToJoin)
%JOINTRACKS  Join tracks together manually
%
%  JOINTRACKS(MATFILE, T) will join tracks in the specified file together.
%  T should be either an array or a cell of arrays specifying which tracks
%  to join together. Note that the function will join all tracks to the
%  first ID specified.
%
%  Example:
%  joinTracks('D:\Work\Projects\massimo\data\20250311\Processed\Movie_A1.mat', [4, 11, 25, 26, 33, 37, 38]);
%
%  joinTracks('D:\Work\Projects\massimo\data\20250311\Processed\Movie_A1.mat', {[4, 11, 25], [2, 9, 16]});

%Parse inputs
if ~exist(matfilePath, 'file')
    error('joinTracks:FileNotFound', ...
        'Could not find file %s.', matfilePath)
end

if ~iscell(tracksToJoin) && ismatrix(tracksToJoin)
    tracksToJoin = {tracksToJoin};
end

load(matfilePath);

tracks = L.tracks;

for iSetsOfTracks = 1:numel(tracksToJoin)

    for xx = 2:numel(tracksToJoin{iSetsOfTracks})

        tracks = joinTrack(tracks, tracksToJoin{iSetsOfTracks}(1), tracksToJoin{iSetsOfTracks}(xx), 'true');
    end

end


[fPath, fn] = fileparts(matfilePath);

save(fullfile(fPath, [fn, '_edited.mat']), 'tracks');

%Remake the movie
nFrames = numel(imfinfo(file));

expandSize = 6;

vid = VideoWriter(fullfile(fPath, [fn, '_edited.avi']));
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

            if ~isnan(ct.Centroid(frameIdx, 1))

                Iout = insertShape(Iout, 'filled-circle', ...
                    [ct.Centroid(frameIdx, 1), ct.Centroid(frameIdx, 2), 2], ...
                    'ShapeColor', 'white');

                Iout = insertText(Iout, [ct.Centroid(frameIdx, 1), ct.Centroid(frameIdx, 2)], ...
                    int2str(ii), 'BoxOpacity', 0, 'TextColor', 'yellow', ...
                    'AnchorPoint', 'CenterTop');
            end

            cc = ct.Centroid(1:frameIdx, :);
            cc(isnan(cc(:, 1)), :) = [];

            if size(cc, 1) > 1

                Iout = insertShape(Iout, 'line', cc, ...
                    'ShapeColor', 'magenta');
            end
        end

    end

    writeVideo(vid, Iout);
end

close(vid)