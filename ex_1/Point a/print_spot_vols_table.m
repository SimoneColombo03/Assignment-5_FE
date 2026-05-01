function print_spot_vols_table(vols_matrix, flat_vols, label)

% PRINT_SPOT_VOLS_TABLE  Pretty printer for a [n_maturities x n_strikes]
% volatility matrix in the same format as the table in the assignment PDF
% (column headers = strikes in %, row headers = maturity in years, body
% values in % with two decimal places).
%
%   NaN entries are printed as "  -  " so that missing rows (e.g. Y=20
%   when no caplet fixes there) do not pollute the output.
%
%   Usage:
%       spot_vols_cap_grid = spot_vols_on_cap_grid(spot_vols_matrix, flat_vols);
%       print_spot_vols_table(spot_vols_cap_grid, flat_vols);
%       print_spot_vols_table(flat_vols.flatVol, flat_vols, 'MARKET FLAT VOLS');
%
%   INPUTS:
%   vols_matrix - [n_maturities x n_strikes] vol matrix in DECIMAL
%   flat_vols   - flat-vol struct (uses .maturity and .strike)
%   label       - (optional) header line printed above the table

    if nargin < 3 || isempty(label)
        label = 'LMM SPOT VOLS ON CAP GRID';
    end

    cap_maturities = flat_vols.maturity(:);
    strikes        = flat_vols.strike(:);

    % Convert decimals -> percentages for display
    vols_pct    = vols_matrix * 100;
    strikes_pct = strikes * 100;

    n_strikes  = numel(strikes);
    line_width = 7 + 8 * n_strikes;

    fprintf('\n%s\n', repmat('=', 1, line_width));
    fprintf('  %s\n', label);
    fprintf('%s\n', repmat('=', 1, line_width));

    % Header row (strikes in %)
    fprintf('%5s |', '');
    for k = 1:n_strikes
        fprintf(' %5.2f |', strikes_pct(k));
    end
    fprintf('\n');
    fprintf('%s\n', repmat('-', 1, line_width));

    % Body rows (one per cap maturity)
    for m = 1:numel(cap_maturities)
        fprintf('%4dY |', cap_maturities(m));
        for k = 1:n_strikes
            v = vols_pct(m, k);
            if isnan(v)
                fprintf(' %5s |', '-');
            else
                fprintf(' %5.2f |', v);
            end
        end
        fprintf('\n');
    end

    fprintf('%s\n\n', repmat('=', 1, line_width));
end