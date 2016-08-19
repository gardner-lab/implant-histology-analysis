classdef Annotator < handle
    %ANNOTATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % image
        name
        file
        image
        
        % annotation file
        annot_file = '';
        
        % annotations
        annotations = [];
        scale = 1; % units/pixels
    end
    
    properties (Access=protected)
        % mode
        mode = 1; % 1 - draw, 2 - scale
        saved = true;
        
        % handles
        win
        axes
        
        % gui elements
        gui_toolbar
        
        % plot handles
        plot_annotations
        plot_other = {};
    end
    
    events
        CloseAnnotator
    end
    
    methods
        function AN = Annotator(file, image, annot_file)
            [path, nm] = fileparts(file);
            
            % load image
            if ~exist('image', 'var') || isempty(image)
                image = imread(file);
            end
            
            % set parameters
            AN.name = nm;
            AN.file = file;
            AN.image = image;
            
            % make color
            color_bg = [0.85 0.85 0.85];
            
            % get screen size
            screen = get(0, 'ScreenSize');
            
            % inital dimensions
            h = size(image, 1) ;
            w = size(image, 2);
            x = max((screen(3) - w) / 2, 0);
            y = max((screen(2) - h) / 2, 0);
            
            % create viewer window
            AN.win = figure('Visible', 'on', 'Name', nm, ...
                'Position', [x y w h], 'NumberTitle', 'off', 'Toolbar', ...
                'none', 'MenuBar', 'none', 'Resize', 'off', 'Color', ...
                color_bg);
            
            % set 
            set(AN.win, 'PaperPositionMode', 'auto');
            set(AN.win, 'InvertHardcopy', 'off');
            set(AN.win, 'Units', 'pixels');
            set(AN.win, 'Pointer', 'crosshair');
            set(AN.win, 'WindowButtonDownFcn', {@AN.cb_clickWindow});
            set(AN.win, 'DeleteFcn', {@AN.cb_closeWindow});
            
            % toolbar
            AN.gui_toolbar = uitoolbar('Parent', AN.win);
            
            % add open button
            [ico, ~, alpha] = imread(fullfile(matlabroot, 'toolbox', 'matlab','icons', 'file_open.png'));
            if isa(ico, 'uint8')
                ico = double(ico) / (256 - 1);
            elseif isa(ico, 'uint16')
                ico = double(ico) / (256 * 256 - 1);
            end
            ico(repmat(alpha == 0, 1, 1, size(ico, 3))) = nan;
            uipushtool('Parent', AN.gui_toolbar, 'CData', ico, ...
                'ClickedCallback', {@AN.cb_load}, 'TooltipString', ...
                'Open');
            
            % add save button
            [ico, ~, alpha] = imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'file_save.png'));
            if isa(ico, 'uint8')
                ico = double(ico) / (256 - 1);
            elseif isa(ico, 'uint16')
                ico = double(ico) / (256 * 256 - 1);
            end
            ico(repmat(alpha == 0, 1, 1, size(ico, 3))) = nan;
            uipushtool('Parent', AN.gui_toolbar, 'CData', ico, ...
                'ClickedCallback', {@AN.cb_save}, 'TooltipString', ...
                'Save');
            
            % add magic button
            [ico, ~, alpha] = imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'tool_shape_ellipse.png'));
            if isa(ico, 'uint8')
                ico = double(ico) / (256 - 1);
            elseif isa(ico, 'uint16')
                ico = double(ico) / (256 * 256 - 1);
            end
            ico(repmat(alpha == 0, 1, 1, size(ico, 3))) = nan;
            uipushtool('Parent', AN.gui_toolbar, 'CData', ico, ...
                'ClickedCallback', {@AN.cb_magic}, 'TooltipString', ...
                'Magic');
            
            % get axes
            AN.axes = axes('Parent', AN.win);
            axis off;
            
            % show image
            imshow(AN.image, 'Parent', AN.axes, 'Border', 'tight');
            pan off;
            
            % auto load annotations if specified or same file name exists
            if exist('annot_file', 'var') && ~isempty(annot_file)
                AN.loadAnnotations(annot_file);
            else
                default_annot_file = [path filesep nm '.mat'];
                if exist(default_annot_file, 'file')
                    AN.loadAnnotations(default_annot_file);
                end
            end
        end
        
        function delete(AN)
            try
                delete(AN.win);
            catch err %#ok<NASGU>
            end
        end
        
        function cb_load(AN, h, event)
            [filename, pathname] = uigetfile({'*.mat', 'MATLAB File (*.mat)'; '*.*', 'All Files'}, 'Load annotations');
            
            % was anceled?
            if isequal(filename, 0) || isequal(pathname, 0)
                return;
            end
            
            % load file
            AN.loadAnnotations(fullfile(pathname, filename));
        end
        
        function cb_save(AN, h, event)
            % figure out default name
            if isempty(AN.annot_file)
                [path, nm] = fileparts(AN.file);
                def_name = [path filesep nm '.mat'];
            else
                def_name = AN.annot_file;
            end
            
            % show save window
            [filename, pathname] = uiputfile({'*.mat', 'MATLAB File (*.mat)'; '*.*', 'All Files'}, 'Save annotations', def_name);
            
            % was anceled?
            if isequal(filename, 0) || isequal(pathname, 0)
                return;
            end
            
            % save
            AN.saveAnnotations(fullfile(pathname, filename));
        end
        
        function cb_clickWindow(AN, h, event)
            % imgca(AN.win)
            pos = get(AN.axes, 'CurrentPoint');
            
            % make sure there is a value
            if size(pos, 1) < 1
                return;
            end
            
            i = pos(1, 1); j = pos(1, 2);
            
            % right click? remove point
            if strcmp(h.SelectionType, 'alt')
                AN.removeClosestAnnotation(i, j);
                return;
            end
            
            % add to annotations
            AN.addAnnotation(i, j);
        end
        
        function cb_magic(AN, h, event)
            fprintf('Number of points: %d\n', size(AN.annotations, 1));
            
            AN.fitEllipse(1);
            AN.fitEllipse(2);
            AN.fitConvexHull();
            AN.distancesToNearestNeighbor();
            
            AN.plot_other{end + 1} = figure;
            scatterhist(AN.annotations(:, 1), AN.annotations(:, 2));
        end
        
        function cb_closeWindow(AN, h, event)
            % nothing to do
            if ~isvalid(AN)
                return;
            end
            
            % is unsaved?
            if ~AN.saved
                % prompt to save
                if strcmp(questdlg('Do you want to save changes before closing?', 'Save Changes', 'No', 'Yes', 'Yes'), 'Yes')
                    AN.cb_save(h, event);
                end
            end
            
            % send notification
            notify(AN, 'CloseAnnotator');
            
            % clear image
            clear AN.image;
        end
        
        function loadAnnotations(AN, fl)
            % load file
            d = load(fl);
            
            % check file
            if ~isfield(d, 'annotations')
                warning('Invalid annotations file.');
                return
            end
            
            if ~strcmp(d.file, AN.file)
                warning('Annotations were potentially for a different image.');
            end
            
            % store file name
            AN.annot_file = fl;
            
            % copy data
            AN.annotations = d.annotations;
            AN.scale = d.scale;
            
            % redraw
            AN.redrawAnnotations();
            
            % mark saved
            AN.saved = true;
        end
        
        function saveAnnotations(AN, fl)
            % extract variables
            name = AN.name; %#ok<NASGU,PROPLC>
            file = AN.file; %#ok<NASGU,PROPLC>
            %image = AN.image; %#ok<NASGU,PROPLC>
            annotations = AN.annotations; %#ok<NASGU,PROPLC>
            scale = AN.scale; %#ok<NASGU,PROPLC>
            
            % do save
            save(fl, '-v7.3', 'name', 'file', 'annotations', 'scale');
            
            % store file name
            AN.annot_file = fl;
            
            % mark saved
            AN.saved = true;
        end
        
        function saveAnnotatedImage(AN, fl)
            print(AN.win, fl, '-djpeg75');
        end
        
        function [density, area, count] = fitEllipse(AN, std)
            if 3 >= size(AN.annotations, 1)
                warning('Insufficient data to fit an ellipse.');
            end
            
            % standard deviation, for scaling
            if ~exist('std', 'var') || isempty(std)
                std = 2;
            end

            % get means (center)
            mu = mean(AN.annotations, 1);
            
            % subtract mean
            annot = bsxfun(@minus, AN.annotations, mu);
            
            % figure out scaling
            conf = 2 * normcdf(std) - 1; % 95% of the population
            sc = chi2inv(conf, 2);
            %fprintf('Ellipse calculated based on: %.1f%%\n', conf * 100);
            
            % eigen value decomposition
            c = annot' * annot ./ (size(annot, 1) - 1);
            c = c * sc;
            [V, D] = eig(c);
            
            % sort, descending order
            [D, ord] = sort(diag(D), 'descend');
            D = diag(D);
            V = V(:, ord);
            
            % generate ellipse
            t = linspace(0,2*pi,100);
            e = [cos(t); sin(t)]; % unit circle
            VV = V * sqrt(D); % scale
            e = bsxfun(@plus, VV * e, mu'); % project unit circle to space
            
            % calculate area
            [c_a, c_b] = inpolygon(AN.annotations(:, 1), AN.annotations(:, 2), e(1, :), e(2, :));
            count = sum(c_a) + sum(c_b);
            area = polyarea(e(1, :) * AN.scale, e(2, :) * AN.scale);
            density = count / area;
            fprintf('** ELLIPSE (conf = %.1f) **\n', conf * 100);
            fprintf('Count: %d\n', count);
            fprintf('Area: %f unit^2\n', area);
            fprintf('Density: %f fibers per unit^2\n', density);
            
            % hold axes
            hold(AN.axes, 'on');
            
            % plot
            AN.plot_other{end + 1} = plot(AN.axes, e(1, :), e(2, :), 'Color', 'g');
            
            % unhold axes
            hold(AN.axes, 'off');
        end
        
        function [density, area, count] = fitConvexHull(AN)
            if 3 >= size(AN.annotations, 1)
                warning('Insufficient data to fit an ellipse.');
            end

            % get means (center)
            mu = mean(AN.annotations, 1);
            
            % subtract mean
            annot = bsxfun(@minus, AN.annotations, mu);
            
            % calculate distances from centroid and use to establish a
            % threshold
            dist = sqrt(sum(annot .^ 2, 2));
            sorted = sort(dist, 'descend');
            threshold = sorted(round(length(dist) * 0.05));
            idx = dist < threshold;
            
            % points in confidence interval
            in_conf = AN.annotations(idx, :);
            
            % convex hull
            k = convhull(in_conf(:, 1), in_conf(:, 2));
            
            % area
            count = size(in_conf, 1);
            area = polyarea(in_conf(k, 1) * AN.scale, in_conf(k,2) * AN.scale);
            density = count / area;
            fprintf('** CONVEX HULL **\n');
            fprintf('Count: %d\n', count);
            fprintf('Area: %f unit^2\n', area);
            fprintf('Density: %f fibers per unit^2\n', density);
            
            % hold axes
            hold(AN.axes, 'on');
            
            AN.plot_other{end + 1} = plot(AN.axes, in_conf(k, 1), in_conf(k,2), 'y');
            
            % unhold axes
            hold(AN.axes, 'off');
        end
        
        function distances = distancesToNearestNeighbor(AN)
            if 1 >= size(AN.annotations, 1)
                warning('Insufficient data to measure distance to nearest neighbors.');
            end
            
            % make distances vector
            n = size(AN.annotations, 1);
            idx = true(1, n);
            distances = zeros(1, n);
            for i = 1:n
                idx(i) = false;
                d = bsxfun(@minus, AN.annotations(idx, :), AN.annotations(i, :));
                distances(i) = sqrt(min(sum(d .^ 2, 2)));
                idx(i) = true;
            end
        end
        
        function drawScale(AN)
            x1 = 120;
            y1 = 300;
            x2 = round(x1 + 100 / AN.scale);
            y2 = y1;
            
            % hold axes
            hold(AN.axes, 'on');
            
            AN.plot_other{end + 1} = plot(AN.axes, [x1 x2], [y1 y2], 'g', 'LineWidth', 3);
            AN.plot_other{end + 1} = text(x1, y1 - 20, '100\mu', 'Color', [0 1 0], 'FontSize', 20, 'FontWeight', 'bold');
            
            % unhold axes
            hold(AN.axes, 'off');
        end
    end
    
    methods (Access=protected)
        function redrawAnnotations(AN)
            % hold axes
            hold(AN.axes, 'on');
            
            % remove existing plot
            if ~isempty(AN.plot_annotations)
                delete(AN.plot_annotations);
                AN.plot_annotations = [];
            end
            
            % remove other plots
            if ~isempty(AN.plot_other)
                for i = 1:numel(AN.plot_other)
                    delete(AN.plot_other{i});
                end
                AN.plot_other = {};
            end
            
            % add new plot
            if ~isempty(AN.annotations)
                AN.plot_annotations = scatter(AN.axes, AN.annotations(:, 1), AN.annotations(:, 2), 10, 'g', 'filled');
            end
            
            % unhold axes
            hold(AN.axes, 'off');
        end
        
        function addAnnotation(AN, i, j)
            % already in the lsit?
            if ~isempty(AN.annotations) && ismember([i j], AN.annotations, 'rows')
                return;
            end
            
            % add to annotations
            AN.annotations = [AN.annotations; i j];
            
            % mark unsaved
            AN.saved = false;
            
            % redraw annotations
            AN.redrawAnnotations();
        end
        
        function removeClosestAnnotation(AN, i, j, max_distance)
            if ~exist('max_distance', 'var') || isempty(max_distance);
                max_distance = 5; %pixels
            end
            
            % no annotations, nothing to remove
            if 0 == size(AN.annotations, 1)
                return;
            end

            % measure distances
            dist = sqrt(sum((AN.annotations - repmat([i j], size(AN.annotations, 1), 1)) .^ 2, 2));

            % find shortest distance
            [v, idx] = min(dist);

            % check max distance
            if v < max_distance
                % remove row
                AN.annotations(idx, :) = [];
            
                % mark unsaved
                AN.saved = false;

                % redraw annotations
                AN.redrawAnnotations();
            end
        end
    end
end
