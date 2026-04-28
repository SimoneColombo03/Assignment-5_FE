function capVols = readCapVols(filename, sheetName)
% READCAPVOLS  Legge la tabella di flat volatilities EUR Cap/Floor da Excel
%
%   capVols = readCapVols(filename) legge il foglio 'Cap Volatilities' dal
%   file Excel specificato e restituisce una struct con i seguenti campi:
%       .maturity     vettore colonna [N x 1]  maturità in anni (double)
%       .strike       vettore riga    [1 x M]  strike in DECIMALE
%       .flatVol      matrice         [N x M]  flat volatilities in DECIMALE
%       .strikePct    vettore riga    [1 x M]  strike in PERCENTO (come da file)
%       .flatVolPct   matrice         [N x M]  flat vol in PERCENTO (come da file)
%       .valuationDate datetime                data di valutazione
%       .sourceFile   string                   path del file letto
%       .sourceSheet  string                   nome del foglio letto
%
%   capVols = readCapVols(filename, sheetName) permette di specificare un
%   nome di foglio diverso (default: 'Cap Volatilities').
%
%   La conversione in decimale (divisione per 100) è applicata di default
%   perché i modelli di pricing (Black-76, bootstrap caplet, ecc.) si
%   aspettano input in decimale. Le versioni in percento sono conservate
%   per ispezione/confronto con la tabella originale.

    if nargin < 2 || isempty(sheetName)
        sheetName = 'Cap Volatilities';
    end

    % -------- Lettura grezza del foglio --------
    raw = readcell(filename, 'Sheet', sheetName);

    % -------- Estrazione valuation date (riga 2, cella A2) --------
    %   Esempio: 'Valuation date: 15-Feb-2008'
    valDate = NaT;
    try
        s = string(raw{2,1});
        tok = regexp(s, '(\d{1,2}-[A-Za-z]{3}-\d{4})', 'match', 'once');
        if ~ismissing(tok) && strlength(tok) > 0
            valDate = datetime(tok, 'InputFormat', 'd-MMM-yyyy', 'Locale', 'en_US');
        end
    catch
        warning('readCapVols:valDate', 'Valuation date non parsata.');
    end

    % -------- Strike (riga 4, da colonna 2 a fine) --------
    headerRow = 4;
    strikeCells = raw(headerRow, 2:end);
    keepStrike  = cellfun(@(x) isnumeric(x) && isscalar(x) && ~isnan(x), strikeCells);
    strikePct   = cell2mat(strikeCells(keepStrike));      % vettore riga, in %
    strikeCols  = find(keepStrike) + 1;                   % indici di colonna nel raw

    % -------- Maturità (colonna A, dalla riga 5 in poi) --------
    matCells = raw(headerRow+1:end, 1);
    matStr   = string(matCells);
    % Pattern del tipo  ^\s*(\d+(?:\.\d+)?)\s*Y\s*$  (case-insensitive)
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
    matRows = find(keepMat) + headerRow;                  % indici di riga nel raw

    % -------- Matrice di flat vol --------
    flatVolPct = nan(numel(matRows), numel(strikeCols));
    for i = 1:numel(matRows)
        for j = 1:numel(strikeCols)
            v = raw{matRows(i), strikeCols(j)};
            if isnumeric(v) && isscalar(v)
                flatVolPct(i,j) = v;
            end
        end
    end

    if any(isnan(flatVolPct), 'all')
        warning('readCapVols:nan', ...
            'Trovati valori mancanti nella matrice di flat vol.');
    end

    % -------- Output struct --------
    capVols = struct();
    capVols.maturity      = matYears;          % anni
    capVols.strike        = strikePct / 100;   % decimale
    capVols.flatVol       = flatVolPct / 100;  % decimale
    capVols.strikePct     = strikePct;         % %
    capVols.flatVolPct    = flatVolPct;        % %
    capVols.valuationDate = valDate;
    capVols.sourceFile    = string(filename);
    capVols.sourceSheet   = string(sheetName);
end