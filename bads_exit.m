paths = genpath(fileparts(mfilename('fullpath')));
paths = strsplit(paths,';');
paths(ismember(paths,fileparts(mfilename('fullpath')))) = [];
rmpath()

