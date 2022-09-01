function options = setupoptions(nvars,defopts,inputArgs)
%INITOPTIONS Initialize OPTIONS struct.

% Assign default values to OPTIONS struct
options = struct();
for f = fieldnames(defopts)'
    if ~isfield(options,f{:}) || isempty(options.(f{:}))
        options.(f{:}) = defopts.(f{:});
    end
end

% Remove comments and trailing empty spaces from options fields
for f = fieldnames(options)'
    if ischar(options.(f{:}))
        idx = find(options.(f{:}) == '%',1);
        if ~isempty(idx); options.(f{:})(idx:end) = []; end        
        idx = find(options.(f{:}) ~= ' ',1,'last');
        if ~isempty(idx); options.(f{:})(idx+1:end) = []; end                
    end
end

% OPTIONS fields that need to be evaluated
evalfields = {'Debug', 'MaxIter', 'MaxFunEvals', 'TolMesh', 'TolStallIters', ...
    'TolFun', 'TolNoise', 'Ninit', 'InitFcn', 'Restarts', 'CacheSize', 'FunValues', 'PeriodicVars', 'OutputFcn', ...
    'TolImprovement', 'ForcingExponent', 'PollMeshMultiplier', 'ForcePollMesh', 'IncumbentSigmaMultiplier', 'ImprovementQuantile', 'FinalQuantile', 'AlternativeIncumbent', 'AdaptiveIncumbentShift', 'FitnessShaping', 'WarpFunc', ...
    'NonlinearScaling', 'gpRescalePoll', 'PollMethod', 'Nbasis', ...
    'Nsearch', 'Nsearchiter', 'ESbeta', 'ESstart', 'SearchImproveFrac', 'SearchScaleSuccess', 'SearchScaleIncremental', 'SearchScaleFailure', 'SearchFactorMin', 'SearchMethod', ...
    'SearchGridNumber', 'MaxPollGridNumber', 'SearchGridMultiplier', 'SearchSizeLocked', 'SearchNtry', 'SearchMeshExpand', 'SearchMeshIncrement', 'SearchOptimize', ...
    'Ndata', 'MinNdata', 'BufferNdata', 'gpSamples', 'MinRefitTime', 'PollTraining', 'DoubleRefit', 'gpMeanPercentile', 'gpMeanRangeFun', ...
    'gpdefFcn', 'gpCluster','RotateGP','gpRadius','UseEffectiveRadius','PollAcqFcn', 'SearchAcqFcn', 'AcqHedge', 'CholAttempts', 'NoiseNudge', 'RemovePointsAfterTries', 'gpFixedMean', 'FitLik', 'gpSVGDiters', ...
    'UncertaintyHandling', 'SpecifyTargetNoise', 'UncertainIncumbent', 'NoiseFinalSamples', 'NoiseSize', 'MeshNoiseMultiplier', 'TolPoI', 'SkipPoll', 'ConsecutiveSkipping', 'SkipPollAfterSearch', 'CompletePoll', 'MinFailedPollSteps', 'NormAlphaLevel', ...
    'AccelerateMesh', 'AccelerateMeshSteps', 'SloppyImprovement', 'MeshOverflowsWarning', 'HessianUpdate', 'HessianAlternate', 'gpWarnings', ...
    'HedgeGamma','HedgeBeta','HedgeDecay', ...
    'TrueMinX', 'OptimToolbox' ...
    };

% Evaluate string options
for f = evalfields
    if ischar(options.(f{:}))
        try
            options.(f{:}) = eval(options.(f{:}));
        catch
            try
                options.(f{:}) = evalbool(options.(f{:}));
            catch
                error('bads:init', ...
                    'Cannot evaluate OPTIONS field "%s".', f{:});
            end
        end
    end
end

% Make cell arrays
cellfields = {'PollMethod','PollAcqFcn','SearchMethod','SearchAcqFcn'};
for f = cellfields
    if ischar(options.(f{:})) || isa(options.(f{:}), 'function_handle')
        options.(f{:}) = {options.(f{:})};
    end
end

% Check if MATLAB's Optimization Toolbox™ is available
if isempty(options.OptimToolbox)
    if exist('fmincon.m','file') && exist('fminunc.m','file') && exist('optimoptions.m','file') ...
            && license('test', 'optimization_toolbox')
        options.OptimToolbox = 1;
    else
        options.OptimToolbox = 0;
        warning('bads:noOptimToolbox', 'Could not find the Optimization Toolbox™. Using alternative optimization functions. This will slightly degrade performance. If you do not wish this message to appear, set OPTIONS.OptimToolbox = 0.');
    end
end

% Check options
if round(options.MaxFunEvals) ~= options.MaxFunEvals || options.MaxFunEvals <= 0
    error('OPTIONS.MaxFunEvals needs to be a positive integer.');
end

if options.ImprovementQuantile > 0.5
    warning('bads:excessImprovementQuantile', 'OPTIONS.ImprovementQuantile is greater than 0.5. This might produce unpredictable behavior. Set OPTIONS.ImprovementQuantile < 0.5 for conservative improvement.');
end

if ~options.SpecifyTargetNoise && ~isempty(options.NoiseSize) && options.NoiseSize(1) <= 0
    error('OPTIONS.NoiseSize, if specified, needs to be a positive scalar for numerical stability.');
end

if options.SpecifyTargetNoise && ...
        ~isempty(options.NoiseSize) && options.NoiseSize(1) > 0
    warning('If OPTIONS.SpecifyTargetNoise is ON, OPTIONS.NoiseSize is ignored. Leave OPTIONS.NoiseSize empty or set it to 0 to silence this warning.');
end

options = checkOptions(options, inputArgs);
end


function options = checkOptions(options, inputArgs, doWarning)
% options = checkOptions(options, inputArgs, doWarning)
%
% options: struct with valid fields
% inputargs: a cell of inputs -> varargin of a higher function
% doWarning: true (default), false
%

if nargin == 2
    doWarning = true;
end

if doWarning
    stack = dbstack(1);
    fcnName = stack(1).name;
else
    fcnName = '';
end

% List of valid options to accept, simple way to deal with illegal user input
validEntries = fieldnames(options);

% Loop over each input name-value pair, check whether name is valid and overwrite fieldname in options structure.
ii = 1;
while ii <=length(inputArgs)
    entry = inputArgs{ii};
    
    [isValid,validEntry] = isValidEntry(validEntries,entry,fcnName,doWarning);
    if ischar(entry) && isValid
        options.(validEntry) = inputArgs{ii+1};
        ii = ii + 2;
        
    elseif isstruct(entry)
        fieldNames = fieldnames(entry);
        for idx = 1:length(fieldNames)
            subentry = fieldNames{idx};
            [isval,validEntry] = isValidEntry(validEntries,subentry,fcnName,doWarning);
            if isval 
                options.(validEntry) = entry.(subentry);
            end
        end
        ii = ii + 1;
    else
        ii = ii + 1;
    end
end
end

function [bool,validEntry] = isValidEntry(validEntries, input, fcnName,doWarning)
% allow input of an options structure that overwrites existing fieldnames with its own, for increased flexibility
bool = false;
validEntry = '';
valIdx = strcmp(input,validEntries); % Check case sensitive

if nnz(valIdx) == 0 && ~isstruct(input) && ischar(input)
    valIdx = strcmpi(input,validEntries); % Check case insensitive
end

if nnz(valIdx) == 0 && ~isstruct(input) && ischar(input)
    valIdx = contains(validEntries,input,'IgnoreCase',true); % Check case insensitive
end

if nnz(valIdx) > 1 && doWarning
    strings = [validEntries(1); strcat(',', validEntries(2:end)) ] ; % removes ' ' at the end when concatenating
    longString = [strings{:}];
    longString = strrep(longString,',',', ');
    error(['-',fcnName,'.m: Option "', input,'" not correct. Allowed options are [', longString, '].'])
elseif nnz(valIdx) > 0 % All else options
    validEntry = validEntries{valIdx};
    bool = true;
elseif doWarning && ~isstruct(input) && ischar(input)
    strings = [validEntries(1); strcat(',', validEntries(2:end)) ] ; % removes ' ' at the end when concatenating
    longString = [strings{:}];
    longString = strrep(longString,',',', ');
    warning(['-',fcnName,'.m: Option "', input,'" not found. Allowed options are [', longString, '].'])
end
end
