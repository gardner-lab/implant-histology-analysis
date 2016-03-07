function ret = batch_summarize(d, ret)

if ~exist('ret', 'var')
    ret = {};
end

files = dir(d);
for i = 1:numel(files)
    nm = files(i).name;
    if files(i).isdir
        % skip special direcruntories
        if strcmp(nm(1), '.')
            continue
        end
        
        % run for subdirectory
        ret = batch_summarize(fullfile(d, nm), ret);
    else
        [~, ~, ext] = fileparts(nm);
        if strcmp(ext, '.mat')
            % get annotation file
            annot_file = fullfile(d, nm);
            
            % get image file
            f = load(annot_file, 'file');
            im_file = f.file;
            
            % load image
            im = imread(im_file);
            
            % load
            an = Annotator(im_file, im, annot_file);
            
            % perform calculations
            [d1, a1, c1] = an.fitConvexHull();
            [d2, a2, c2] = an.fitEllipse(1);
            [d3, a3, c3] = an.fitEllipse(2);
            distances = an.distancesToNearestNeighbor();
            
            % draw scale
            an.drawScale();
            
            % save
            an.saveAnnotatedImage(sprintf('%d.jpg', 1 + (length(ret) / 3)));
            
            % scatter histogram
            f = figure;
            scatterhist(an.annotations(:, 1) * an.scale, an.annotations(:, 2) * an.scale);
            print(f, sprintf('%d.png', 1 + (length(ret) / 3)), '-dpng', '-r300');
            close(f);
            
            % append to ret
            ret{end + 1} = im_file;
            ret{end + 1} = [size(an.annotations, 1) d1 a1 c1 d2 a2 c2 d3 a3 c3];
            ret{end + 1} = distances;
            
            delete(an);
        end
    end
end

end