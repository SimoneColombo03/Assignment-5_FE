function spot_vols_cap_grid = spot_vols_on_cap_grid(spot_vols_matrix, flat_vols)

% SPOT_VOLS_ON_CAP_GRID  Sample the caplet-by-caplet spot vol surface on
% the cap-maturity grid by selecting the caplet that FIXES at maturity Y
% (and pays at Y + 3m).
%
%   With quarterly resets and the first deterministic Libor excluded, the
%   caplet that fixes at year Y has index
%
%       row index of caplet fixing at Y  =  4 * Y
%
%   So Y = 1 -> row 4 (fix 1y, pay 1.25y), Y = 2 -> row 8, ...,
%   Y = 10 -> row 40, Y = 12 -> row 48, Y = 15 -> row 60.
%
%   For Y = 20 the caplet would have index 80, but the stripping grid only
%   has 79 caplets (the last one fixes at 19.75y and pays at 20y). For
%   that maturity we therefore return NaN -- the user is informed that
%   this point is not available on the chosen grid.
%
%   IMPORTANT (semantic note):
%   The resulting matrix is NOT directly comparable with flat_vols.flatVol.
%   Each cell here is the spot vol of a SINGLE caplet (the one fixing at
%   year Y), while a market flat vol is the unique vol that, applied to
%   ALL caplets of the cap, reproduces the cap price.
%
%   INPUTS:
%   spot_vols_matrix  - [M x n_strikes] caplet spot vols (rows = caplets)
%   flat_vols         - flat-vol struct with field .maturity (years)
%
%   OUTPUT:
%   spot_vols_cap_grid - [n_maturities x n_strikes] sampled spot vols.
%                        Rows whose target index exceeds M are returned NaN.

    cap_maturities = flat_vols.maturity(:);
    n_maturities   = numel(cap_maturities);
    n_strikes      = size(spot_vols_matrix, 2);

    % Index of the caplet fixing at year Y (see header):  row = 4 * Y
    row_idx = round(4 * cap_maturities);

    % Pre-allocate with NaN: any row whose index is out of range stays NaN.
    spot_vols_cap_grid = nan(n_maturities, n_strikes);

    valid = row_idx <= size(spot_vols_matrix, 1);
    spot_vols_cap_grid(valid, :) = spot_vols_matrix(row_idx(valid), :);

    % Inform the user if any maturity could not be sampled (e.g. Y = 20
    % when the stripping grid only goes up to caplet 79 / fix 19.75y).
    if any(~valid)
        missing_Y = cap_maturities(~valid);
        fprintf(['spot_vols_on_cap_grid: WARNING - the following cap ', ...
                 'maturities have no caplet fixing at Y on the available ', ...
                 'stripping grid (NaN returned): ']);
        fprintf('%dY ', missing_Y);
        fprintf('\n');
    end
end