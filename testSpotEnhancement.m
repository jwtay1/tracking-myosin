clearvars
clc

file = 'D:\Documents\OneDrive - UCB-O365\Shared\Share with Leinwand Lab\Massimo\Plate2 Delta38_5pMoles009_substack.tif';

%%
I = double(imread(file, 100));

I2 = double(imread(file, 100));

imshow(I, [])