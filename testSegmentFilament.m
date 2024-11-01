clearvars
clc

file = 'C:\Users\Jian Tay\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Myosin tracking\Movie_selections\RGB_plate1_10pM_002_reimage001_A.tif';

I = imread(file, 100);

Ifil = I(:, :, 1);

%Segment
mask = imbinarize(Ifil);
mask = imopen(mask, strel('disk', 2));

imshowpair(Ifil, mask)