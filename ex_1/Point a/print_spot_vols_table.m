function print_spot_vols_table(vols_matrix, flat_vols, label, is_fallback)

% PRINT_SPOT_VOLS_TABLE  Pretty printer for a [n_maturities x n_strikes]
% volatility matrix in the same format as the table in the assignment PDF
% (column headers = strikes in %, row headers = maturity in years from
% flat_vols.maturity, body values in % with two decimal places).
%
%   If the optional argument is_fallback is provided, rows flagged as
%   fallback are annotated with "(19.75y)" to make the substitution
%   explicit (used when no caplet fixes exactly at year Y and the closest
%   available one is sampled instead).
%
%   Usage:
%       [vols, ~, fb] = spot_vols_on_cap_grid(...);
%       print_spot_vols_table(vols, flat_vols, 'LMM SPOT VOLS', fb);
%       print_spot_vols_table(flat_vols.flatVol, flat_vols, 'MARKET FLAT VOLS');
%
%   INPUTS:
%   vols_matrix  - [n_maturities x n_strikes] vol matrix in DECIMAL
%   flat_vols    - flat-vol struct (uses .maturity and .strike)
%   label        - (optional) header line printed above the table
%   is_fallback  - (optional) [n_maturities x 1] logical flag

    if nargin < 3 || isempty(label),  label       = 'LMM SPOT VOLS ON CAP GRID'; end
    if nargin < 4,                    is_fallback = []; end

    cap_maturities = flat_vols.maturity(:);
    strikes        = flat_vols.strike(:);

    % Convert decimals -> percentages for display
    vols_pct    = vols_matrix * 100;
    strikes_pct = strikes * 100;

    n_strikes = numel(strikes);

    % Build all row labels first, so we can size the column to fit them.
    n_maturities = numel(cap_maturities);
    row_lbls = cell(n_maturities, 1);
    for m = 1:n_maturities
        Y = cap_maturities(m);
        if ~isempty(is_fallback) && is_fallback(m) && Y == 20
            % Hard-coded annotation: the only fallback expected on the
            % 20Y maturity (no caplet fixes at 20y, closest is 19.75y).
            row_lbls{m} = sprintf('%dY (19.75y)', Y);
        else
            row_lbls{m} = sprintf('%dY', Y);
        end
    end
    header_w   = max(cellfun('length', row_lbls)) + 1;
    line_width = header_w + 2 + 8 * n_strikes;

    fprintf('\n%s\n', repmat('=', 1, line_width));
    fprintf('  %s\n', label);
    fprintf('%s\n', repmat('=', 1, line_width));

    % Header row (strikes in %)
    fprintf('%*s |', header_w, '');
    for k = 1:n_strikes
        fprintf(' %5.2f |', strikes_pct(k));
    end
    fprintf('\n');
    fprintf('%s\n', repmat('-', 1, line_width));

    % Body rows
    for m = 1:n_maturities
        fprintf('%*s |', header_w, row_lbls{m});
        for k = 1:n_strikes
            fprintf(' %5.2f |', vols_pct(m, k));
        end
        fprintf('\n');
    end

    fprintf('%s\n\n', repmat('=', 1, line_width));
end