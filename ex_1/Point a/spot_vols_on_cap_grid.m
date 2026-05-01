function [spot_vols_cap_grid, sampled_T_expiry, is_fallback] = ...
    spot_vols_on_cap_grid(spot_vols_matrix, flat_vols, spot_vol_parameters)

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
%   FALLBACK FOR OUT-OF-RANGE MATURITIES:
%   For Y = 20 the caplet would have index 80, but the stripping grid only
%   goes up to caplet 79 (which fixes at 19.75y and pays at 20y). In this
%   case we fall back to the last available caplet (row 79) and flag the
%   row as "fallback" in the third output, so that the caller can mark it
%   in the printout.
%
%   IMPORTANT (semantic note):
%   The resulting matrix is NOT directly comparable with flat_vols.flatVol.
%   Each cell here is the spot vol of a SINGLE caplet (the one fixing at
%   year Y, or the closest available one), while a market flat vol is the
%   unique vol that, applied to ALL caplets of the cap, reproduces the
%   cap price.
%
%   INPUTS:
%   spot_vols_matrix     - [M x n_strikes] caplet spot vols (rows = caplets)
%   flat_vols            - flat-vol struct with field .maturity (years)
%   spot_vol_parameters  - struct from compute_caplets_maturities, used to
%                          report the actual T_expiry of each sampled row
%
%   OUTPUTS:
%   spot_vols_cap_grid - [n_maturities x n_strikes] sampled spot vols
%   sampled_T_expiry   - [n_maturities x 1] actual reset time (Act/365)
%                        of the caplet picked for each maturity. Differs
%                        slightly from Y because of business-day adjustments
%                        on the quarterly grid.
%   is_fallback        - [n_maturities x 1] logical, true ONLY for rows
%                        where there is NO caplet fixing at Y in the grid
%                        and we substituted the last available one
%                        (typically only the 20Y row).

    cap_maturities = flat_vols.maturity(:);
    n_maturities   = numel(cap_maturities);
    n_strikes      = size(spot_vols_matrix, 2);
    M              = size(spot_vols_matrix, 1);

    % Index of the caplet fixing at year Y (see header):  row = 4 * Y
    row_idx_target = round(4 * cap_maturities);

    % Out-of-range maturities -> fallback to last available caplet
    is_fallback        = row_idx_target > M;
    row_idx            = row_idx_target;
    row_idx(is_fallback) = M;

    % Sample
    spot_vols_cap_grid = spot_vols_matrix(row_idx, :);
    sampled_T_expiry   = spot_vol_parameters.T_expiry(row_idx);
end