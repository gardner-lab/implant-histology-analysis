function start_analyzer()
%START_ANALYZER Summary of this function goes here
%   Detailed explanation goes here

% global values
g_annotators = {};

% common values
color_bg = [0.85 0.85 0.85];
screen = get(0, 'ScreenSize');
height = 55;
width = 130;

% Create the main window
win_main = figure('Visible', 'on', 'Name', 'Analyze Histology', ...
    'Position', [0 screen(4) - height width height], ...
    'NumberTitle', 'off', 'Toolbar', 'none', 'Resize', 'off', ...
    'MenuBar', 'none', 'Color', color_bg);
set(win_main, 'PaperPositionMode','auto');
set(win_main, 'InvertHardcopy','off');
set(win_main, 'Units','pixels');
set(win_main, 'DeleteFcn', {@cb_closeWindow});
% set(win_main, 'WindowButtonDownFcn', {@p_eventMouse});
% set(win_main, 'KeyPressFcn', {@p_eventKeyboard});
% set(win_main, 'KeyReleaseFcn', {@p_eventKeyboard});

gui_button_load_img = uicontrol(win_main, 'Style', 'pushbutton', ...
    'String', 'Load Image', 'BackgroundColor', color_bg, ...
    'Position', [15 15 100 25], 'Callback', {@cb_loadImage});

% run setup
setup();

%% Setup
    function setup()
    end

%% Loading
    function [success, err] = load_image(file)
        err = '';
        
        % read image
        try
            img = imread(file);
        catch err
            % success = false
            success = 0;
            return;
        end
        
        % set the image
        an = Annotator(file, img);
        g_annotators{end + 1} = an;
        success = 1;
    end

%% Callbacks
    function cb_loadImage(h, event)
        [filename, pathname] = uigetfile({'*.bmp;*.iml;*.png;*.jpg;*.tif', 'Image Files (*.jpg, *.png, *.tif, *.bmp, *.iml)'}, 'Pick an image');
        
        % canceled
        if isequal(filename, 0) || isequal(pathname, 0)
            return;
        end
        
        % load image
        [success, err] = load_image([pathname filename]);
        
        % error?
        if 0 == success
            disp(err);
            msgbox('Unable to read the specified file.', 'Error', 'error');
        end
    end

    function cb_closeWindow(h, event)
        fprintf('Cleaning up...\n');
        
        % clean up
        for i = 1:numel(g_annotators)
            delete(g_annotators{i});
        end
    end
end

