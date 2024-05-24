clearvars
clc

load('C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\Processed\20240524_test\RGB_plate2_reimage_GFP_5perc_HaloMyosin10pM646_25perc_31ms_012_A.mat');

%orImage = imread('C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\data\Movie_selections\RGB_plate2_reimage_GFP_5perc_HaloMyosin10pM646_25perc_31ms_019_B.tif');
%mask = imread('C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\Processed\20240523\RGB_100pm003_A_B.tif');

%%

%Remove stationary particles
figure;
hold on
for ii = 1:L.NumTracks

    ct = getTrack(L, ii);
        
    %Compute the displacement at each frame
    displacementStep = [0; sqrt(sum((diff(ct.Centroid, 1)).^2, 2))];

    %Classify if particle is moving or not
    isMoving = displacementStep > 1.75;

    %Classify if particle is moving or not
    if nnz(isMoving) >= 3 %(0.1 * numel(ct.Frames))
        % classification = 'moving';
        plot(ct.Centroid(:, 1), ct.Centroid(:, 2), 'g')

        if ~exist('filteredTracks', 'var')
            filteredTracks = ct;
        else
            filteredTracks = [filteredTracks; ct];
        end
       
    else
        % classification = 'immobile';
        plot(ct.Centroid(:, 1), ct.Centroid(:, 2), 'r')
    end

end
hold off

%%
resizeFactor = 8;

%Make a video showing only moving particles
vid = VideoWriter('test.avi');
vid.FrameRate = 5;
open(vid)

nFrames = numel(imfinfo(file));


for iFrame = 1:nFrames

    I = imread(file, iFrame);
    I = I(cropRange(1):cropRange(2), cropRange(3):cropRange(4),:);
    I = imresize(I, resizeFactor);
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
