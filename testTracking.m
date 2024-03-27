clearvars
clc

file = 'D:\Documents\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Massimo\Plate2 Delta38_5pMoles009_substack.tif';

nFrames = numel(imfinfo(file));

%%

L = LAPLinker;
L.MaxTrackAge = 1;
L.LinkScoreRange = [0 8];

vid = VideoWriter('test.avi');
vid.FrameRate = 5;
open(vid)

for iT = 100:200

    I = double(imread(file, iT));
%    I = medfilt2(I, [3 3]);

    I2 = imresize(I, 2, 'nearest');

    dg1 = imgaussfilt(I2, 1);
    dg2 = imgaussfilt(I2, 6);

    dog = dg1 - dg2;

    spots = dog > 600;

    cellMask = I2 == 0;
    cellMask = imdilate(cellMask, strel('disk', 10));
    % showoverlay(spots, bwperim(cellMask))

    spots(cellMask) = 0;

    spots = bwareaopen(spots, 2);
    % imshow(spots)

    % showoverlay(I2, spots, 'Opacity', 30);

    % spots = imresize(spots, 0.5, 'nearest');
    
    data = regionprops(spots, 'Centroid');

    L = assignToTrack(L, iT, data);

    Iout = showoverlay(I2, spots, 'Opacity', 30);

    for ii = L.activeTrackIDs

        ct = getTrack(L, ii);

        Iout = insertText(Iout, [ct.Centroid(end, 1), ct.Centroid(end, 2)], ...
            int2str(ii), 'BoxOpacity', 0, 'TextColor', 'yellow', ...
            'AnchorPoint', 'Center');

    end

    writeVideo(vid, Iout);

    % showoverlay(I2, spots)
end

close(vid)


save('test.mat', 'L')