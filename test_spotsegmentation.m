clearvars
clc

file = 'D:\Documents\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\data\test2\Movie_1_RGB_inverted_clearoutside_adjust.tif';

MT = FreeMyosinTracker;
%%

for ii = 1:100
    I = imread(file, ii);
    I = I(:, :, 1);

    mask = MT.identifySpots(I);

    MT.showoverlay(I, mask, 'Opacity', 40)
    %pause(0.05)
end