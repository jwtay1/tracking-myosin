clearvars
clc

%Test file
file = 'C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\Movie_selections\RGB_plate1_10pM_002_reimage001_A.tif';

%Number of frames
nFrames = numel(imfinfo(file));

%Set up linking object
L = LAPLinker;
L.MaxTrackAge = 1;
L.LinkScoreRange = [0 8];

vid = VideoWriter('test20240517.avi');
vid.FrameRate = 5;
open(vid)

%Add distance to red?

for iT = 1:nFrames

    %Read image
    Irgb = imread(file, iT);

    %Find myosin particles
    Ispot = double(Irgb(:, :, 2));
    
    %Expand image to make it easier to identify particles
    I2 = imresize(Ispot, 2, 'nearest');    

    dg1 = imgaussfilt(I2, 1);
    dg2 = imgaussfilt(I2, 6);

    dog = dg1 - dg2;

    spots = dog > 50;
    spots = bwareaopen(spots, 2);
    % imshow(spots)

    % showoverlay(I2, spots, 'Opacity', 30);

    % spots = imresize(spots, 0.5, 'nearest');
    
    if ~any(spots, 'all')
        break;
    end

    %Identify filament
    Ifil = imresize(Irgb(:, :, 1), 2, 'nearest');

    %Segment
    filaments = imbinarize(Ifil);
    filaments = imopen(filaments, strel('disk', 2));
    
    %Measure distance to closest filament pixel
    dist = bwdist(filaments);

    %Measure amount of red under the particle
    data = regionprops(spots, Ifil, 'Centroid', 'MeanIntensity');

    for ii = 1:numel(data)
        loc = round(data(ii).Centroid);

        data(ii).Distance = dist(loc(2), loc(1));
    end

    L = assignToTrack(L, iT, data);

    Iout = showoverlay(I2, spots, 'Opacity', 30);
    Iout = showoverlay(Iout, bwperim(filaments), 'color', [1 1 0]);

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