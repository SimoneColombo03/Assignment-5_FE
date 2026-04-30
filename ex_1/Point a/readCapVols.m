function capVols = readCapVols(filename, sheetName)
% READCAPVOLS Reads the EUR Cap/Floor flat volatility table from Excel.
%
% INPUTS:
%   filename  - [String] Full path to the Excel file.
%   sheetName - [String] Name of the sheet (default: 'Cap Volatilities').
%
% OUTPUT:
%   capVols   - [Struct] Containing the following fields:
%       .maturity      : [N x 1] Column vector of maturities in years.
%       .strike        : [1 x M] Row vector of strikes (Decimal).
%       .flatVol       : [N x M] Matrix of flat volatilities (Decimal).
%       .strikePct     : [1 x M] Strikes as percentages (raw format).
%       .flatVolPct    : [N x M] Flat vols as percentages (raw format).
%       .valuationDate : [Datetime] Date of the volatility surface.
%       .sourceFile    : [String] Path to the processed file.
%       .sourceSheet   : [String] Name of the processed sheet.
%
% NOTE: Models like Black-76 and Caplet Bootstrapping require inputs in 
% decimal format. This function converts percentages by dividing by 100 
% by default while preserving raw versions for comparison.


    % Set default sheet name if not provided
    if nargin < 2 || isempty(sheetName)
        sheetName = 'Cap Volatilities';
    end

    % Raw Data Extraction
    % Read the entire sheet into a cell array for flexible parsing
    raw = readcell(filename, 'Sheet', sheetName);

    % Valuation Date Parsing (Row 2, Column A)
     valDate = NaT;
    try
        s = string(raw{2,1});
        % Extract date pattern using RegEx
        tok = regexp(s, '(\d{1,2}-[A-Za-z]{3}-\d{4})', 'match', 'once');
        if ~ismissing(tok) && strlength(tok) > 0
            valDate = datetime(tok, 'InputFormat', 'd-MMM-yyyy', 'Locale', 'en_US');
        end
    catch
        warning('readCapVols:valDate', 'Could not parse Valuation Date.');
    end

    % Strike Extraction (Header Row 4)
    % Identifies numeric cells starting from Column B onwards
    headerRow = 4;
    strikeCells = raw(headerRow, 2:end);
    keepStrike  = cellfun(@(x) isnumeric(x) && isscalar(x) && ~isnan(x), strikeCells);
    strikePct   = cell2mat(strikeCells(keepStrike));      % Row vector, in %
    strikeCols  = find(keepStrike) + 1;                   % Column indices in raw data

    % Maturity Extraction (Column A, starting Row 5)
    % Parses strings like "1Y", "2.5y" into numeric values
    matCells = raw(headerRow+1:end, 1);
    matStr   = string(matCells);
    % RegEx pattern: digit(s) followed by 'Y' or 'y'
    tokens   = regexp(matStr, '^\s*(\d+(?:\.\d+)?)\s*[Yy]\s*$', 'tokens', 'once');
    keepMat  = ~cellfun('isempty', tokens);
    matYears = zeros(sum(keepMat), 1);
    
    k = 0;
    for i = 1:numel(tokens)
        if keepMat(i)
            k = k + 1;
            matYears(k) = str2double(tokens{i}{1});
        end
    end
    matRows = find(keepMat) + headerRow;                  % Row indices in raw data

    % Volatility Matrix Construction
    % Iterates through identified rows and columns to extract numeric vols
    flatVolPct = nan(numel(matRows), numel(strikeCols));
    for i = 1:numel(matRows)
        for j = 1:numel(strikeCols)
            v = raw{matRows(i), strikeCols(j)};
            if isnumeric(v) && isscalar(v)
                flatVolPct(i,j) = v;
            end
        end
    end

    % Warning if the surface contains missing values[cite: 11]
    if any(isnan(flatVolPct), 'all')
        warning('readCapVols:nan', 'Missing values found in the flat vol matrix.');
    end

    % Structure Assembly
    % Convert to decimal for financial modeling
    capVols = struct();
    capVols.maturity      = matYears;          % in years
    capVols.strike        = strikePct / 100;   % converted to decimal
    capVols.flatVol       = flatVolPct / 100;  % converted to decimal
    capVols.strikePct     = strikePct;         % original %
    capVols.flatVolPct    = flatVolPct;        % original %
    capVols.valuationDate = valDate;
    capVols.sourceFile    = string(filename);
    capVols.sourceSheet   = string(sheetName);
end