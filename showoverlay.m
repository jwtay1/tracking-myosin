function varargout = showoverlay(img, mask, varargin)
%SHOWOVERLAY  Overlays a mask on to a base image
%
%  SHOWOVERLAY(I, M) will overlay mask M over the image I, displaying it in
%  a figure window.
%
%  C = SHOWOVERLAY(I, M) will return the composited image as a matrix
%  C. This allows multiple masks to be composited over the same image. C
%  should be of the same class as the input image I. However, if the input
%  image I is a double, the output image C will be normalized to between 0
%  and 1.
%
%  Optional parameters can be supplied to the function to modify both the
%  color and the transparency of the masks:
%
%     'Color' - 1x3 vector specifying the color of the overlay in 
%               normalized RGB coordinates (e.g. [0 0 1] = blue)
%
%     'Transparency' - Value between 0 - 100 specifying the alpha level of
%                      the overlay                      
%
%  Examples:
%
%    %Load a test image
%    testImg = imread('cameraman.tif');
%
%    %Generate a masked region
%    maskIn = false(size(testImg));
%    maskIn(50:70,50:200) = true;
%
%    %Store the image to a new variable
%    imgOut = SHOWOVERLAY(testImg, maskIn);
%
%    %Generate a second mask
%    maskIn2 = false(size(testImg));
%    maskIn2(100:180, 50:100) = true;
%
%    %Composite and display the second mask onto the same image as a
%    %magenta layer with 50% transparency
%    SHOWOVERLAY(imgOut, maskIn2, 'Color', [1 0 1], 'Transparency', 50);

% Author: Jian Wei Tay (jian.tay@colorado.edu)
% Version 2018-Feb-01

ip = inputParser;
ip.addParameter('Color',[0 1 0]);
ip.addParameter('Opacity',100);
ip.addParameter('Normalize', true);
ip.parse(varargin{:});

alpha = ip.Results.Opacity / 100;

%Get the original image class
imageClass = class(img);
imageIsInteger = isinteger(img);

% %Process the input image
if ip.Results.Normalize
    img = double(img);
    img = img ./ max(img(:));
end

if size(img,3) == 1
    %Convert into an RGB image
    img = repmat(img, 1, 1, 3);
elseif size(img,3) == 3
    %Do nothing
else
    error('showoverlay:InvalidInputImage',...
        'Expected input to be either a grayscale or RGB image.');
end

%Process the mask
mask = double(mask);
mask = mask ./ max(mask(:));

if size(mask,3) == 1
    %Convert mask into an RGB image
    %mask = repmat(mask, 1, 1, 3);
    
    replacePx = mask ~= 0;
    
    for iC = 1:3
        %mask(:,:,iC) = mask(:,:,iC) .* ip.Results.Color(iC);
        
        currC = img(:,:,iC);
        currC(replacePx) = (currC(replacePx) .* (1 - alpha)) + (mask(replacePx) .* alpha .* ip.Results.Color(iC));
        
        img(:,:,iC) = currC;        
    end
    
    
elseif size(mask,3) == 3
    
    %Make the composite image
    replacePx = mask ~= 0;
    
    img(replacePx) = img(replacePx) .* (1 - alpha) + mask(replacePx) .* alpha;
    
else
    error('showoverlay:InvalidMask',...
        'Expected mask to be either a logical or RGB image.');
end


%Recast the image into the original image class
if imageIsInteger
    multFactor = double(intmax(imageClass));
    img = img .* multFactor;
    img = cast(img, imageClass);
else
    %multFactor = 1;
end



%Produce the desired outputs
if nargout == 0
    imshow(img,[])
else
    varargout = {img};
end

end