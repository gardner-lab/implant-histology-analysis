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
        annotations = []; % rows: points, columns: x, y, type
        scale = 1; % units/pixels
    end
    
    properties (Access=protected)
        % mode
        mode = 1; % 1 - draw, 2 - scale
        saved = true;
        
        % annotation types
        annot_type = 1; % current annotation type
        annot_types = {'Fiber', 'Neuron'}; % names for annotation types
        annot_colors = [0 1 0; 1 0.5 0]; % colors for annotation types
        
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
            
            % add scale button
            [ico, ~, alpha] = imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'tool_line.png'));
            if isa(ico, 'uint8')
                ico = double(ico) / (256 - 1);
            elseif isa(ico, 'uint16')
                ico = double(ico) / (256 * 256 - 1);
            end
            ico(repmat(alpha == 0, 1, 1, size(ico, 3))) = nan;
            uipushtool('Parent', AN.gui_toolbar, 'CData', ico, ...
                'ClickedCallback', {@AN.setScale}, 'TooltipString', ...
                'Set Scale');
            
            % add layers button
            [ico, ~, alpha] = imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'tool_legend.png'));
            if isa(ico, 'uint8')
                ico = double(ico) / (256 - 1);
            elseif isa(ico, 'uint16')
                ico = double(ico) / (256 * 256 - 1);
            end
            ico(repmat(alpha == 0, 1, 1, size(ico, 3))) = nan;
            uipushtool('Parent', AN.gui_toolbar, 'CData', ico, ...
                'ClickedCallback', {@AN.cb_showLayers}, 'TooltipString', ...
                'Show layers');
            
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
            
            % add type buttons
            for i = 1:length(AN.annot_types)
                nice_name = AN.annot_types{i};
                color = AN.annot_colors(i, :);
                
                width = 16;
                height = 16;
                
                ico = nan(height, width, 3);
                [x, y] = meshgrid(1:width, 1:height);
                mask = ((x - (width + 1) / 2) .^ 2 + (y - (height + 1) / 2) .^ 2) < ((min(width, height) / 2) ^ 2);
                
                ico(cat(3, mask, false(height, width), false(height, width))) = color(:, 1);
                ico(cat(3, false(height, width), mask, false(height, width))) = color(:, 2);
                ico(cat(3, false(height, width), false(height, width), mask)) = color(:, 3);
                
                if i == 1
                    sep = 'on';
                    state = 'on';
                else
                    sep = 'off';
                    state = 'off';
                end
                
                uitoggletool('Parent', AN.gui_toolbar, 'CData', ico, ...
                    'ClickedCallback', {@AN.cb_selectAnnotationType, i}, 'TooltipString', ...
                    nice_name, 'Separator', sep, 'State', state);
            end
            
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
            
            % no type? do nothing
            if isempty(AN.annot_type)
                return;
            end
            
            % add to annotations
            AN.addAnnotation(i, j, AN.annot_type);
        end
        
        function cb_showLayers(AN, h, event)
            names = {'NeuN', 'Green', 'DAPI'};
            
            for i = 1:size(AN.image, 3)
                % skip green
                if i == 2
                    continue
                end
                
                % get image
                cur = imadjust(AN.image(:, :, i));
                
                % make figure
                f = figure('Name', names{i}, 'NumberTitle', 'off');
                
                % make axes
                ax = axes('Parent', f);
                axis off;
                imshow(cur, 'Parent', ax, 'Border', 'tight');
                pan off;
            end
        end
        
        function cb_magic(AN, h, event)
            fprintf('Number of points: %d\n', size(AN.annotations, 1));
            
            AN.fitEllipse(1);
            AN.fitEllipse(2);
            AN.fitConvexHull();
            AN.distancesToNearestNeighbor();
            
            AN.plot_other{end + 1} = figure;
            scatterhist(AN.annotations(:, 1), AN.annotations(:, 2));
            title('All annotations');
            
            % multiple annotation types?
            types = unique(AN.annotations(:, 3));
            if 1 < length(types)
                for i = 1:length(types)
                    idx = AN.annotations(:, 3) == types(i);
                    
                    % plot
                    AN.plot_other{end + 1} = figure;
                    scatterhist(AN.annotations(idx, 1), AN.annotations(idx, 2));
                    if types(i) <= length(AN.annot_types)
                        title(sprintf('Annotation %s', AN.annot_types{types(i)}));
                        fprintf('Number of %s: %d\n', AN.annot_types{types(i)}, sum(idx));
                    else
                        title(sprintf('Annotation %d', types(i)));
                        fprintf('Number of annotation %d: %d\n', types(i), sum(idx));
                    end
                end
            end
        end
        
        function cb_selectAnnotationType(AN, h, event, annot_type)
            if strcmp(h.State, 'on')
                % set current annotation type
                AN.annot_type = annot_type;
                
                % uncheck other boxes
                for i = 1:length(h.Parent.Children)
                    if strcmp(class(h.Parent.Children(i)), class(h)) && h.Parent.Children(i) ~= h
                        h.Parent.Children(i).State = 'off';
                    end
                end
            else
                % clear annotation type
                AN.annot_type = [];
            end
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
            % backwards compatible...
            if 3 == size(d.annotations, 2)
                AN.annotations = d.annotations;
            else
                AN.annotations = [d.annotations ones(size(d.annotations, 1), 1)];
            end
            AN.scale = d.scale;
            
            % redraw
            AN.redrawAnnotations();
            
            % draw scale
            AN.drawScale();
            
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
            mu = mean(AN.annotations(:, 1:2), 1);
            
            % subtract mean
            annot = bsxfun(@minus, AN.annotations(:, 1:2), mu);
            
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
            c = inpolygon(AN.annotations(:, 1), AN.annotations(:, 2), e(1, :), e(2, :));
            count = sum(c);
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
        
        function setScale(AN, h, event)
            if AN.scale == 1
                def = {''};
            else
                def = {sprintf('%.5f', AN.scale)};
            end
            answer = inputdlg('Enter scale (\mu m/px):', 'Set Scale', 1, def, struct('Interpreter', 'tex'));
            
            if ~isempty(answer)
                new_scale = str2double(answer{:});
                if AN.scale ~= new_scale && new_scale > 0 && new_scale < 1000
                    AN.scale = new_scale;
                    AN.saved = false;
                    AN.drawScale();
                end
            end
        end
        
        function drawScale(AN)
            x1 = 20;
            y1 = 100;
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
                % get types and colors
                colors = AN.annot_colors;
                m_type = max(AN.annotations(:, 3));
                if m_type > size(AN.annot_colors, 1)
                    colors = [colors; lines(m_type - size(AN.annot_colors, 1))];
                end
                
                % plot
                AN.plot_annotations = scatter(AN.axes, AN.annotations(:, 1), AN.annotations(:, 2), 10, colors(AN.annotations(:, 3), :), 'filled');
            end
            
            % unhold axes
            hold(AN.axes, 'off');
        end
        
        function addAnnotation(AN, i, j, type)
            % already in the lsit?
            if ~isempty(AN.annotations) && ismember([i j type], AN.annotations, 'rows')
                return;
            end
            
            % add to annotations
            AN.annotations = [AN.annotations; i j type];
            
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
            dist = sqrt(sum((AN.annotations(:, [1 2]) - repmat([i j], size(AN.annotations, 1), 1)) .^ 2, 2));

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
