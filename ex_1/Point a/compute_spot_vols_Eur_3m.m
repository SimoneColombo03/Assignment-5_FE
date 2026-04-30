function spot_vols_matrix = compute_spot_vols_Eur_3m(flat_vols,spot_vol_parameters)

% COMPUTE_SPOT_VOLS_EUR_3M  Strip caplet spot vols on the Euribor 3m grid for
% every strike of the flat-vol surface.
%
%   For each column of flat_vols.flatVol (one strike), runs the cap stripping
%   procedure of bootstrap_vol and returns a matrix of caplet spot vols whose
%   rows are the quarterly Euribor 3m caplets and whose columns are the
%   strikes of the input surface.
%
%   The inputs fwd_libor, yf_caplets, T_expiry, r_eff are assumed to come
%   from compute_caplets_maturities and therefore already exclude the first
%   (deterministic) Libor: their length is M = 4*maxY - 1.
%
%   INPUTS: 
%   flat_vols    - struct with fields:
%                    .strike   : row vector of strikes (decimal)
%                    .maturity : column vector of cap maturities in years
%                    .flatVol  : matrix [n_maturities x n_strikes] of flat
%                                cap vols at each (maturity, strike)
%   fwd_libor    - column of forward Libor (length M)
%   yf_caplets   - column of Act/360 year fractions (length M)
%   T_expiry     - column of Act/365 reset times (length M)
%   r_eff        - column of effective continuous rates (length M)
%
%   OUTPUT:
%   spot_vols_matrix - matrix [M x n_strikes] of caplet spot vols.

    strikes        = flat_vols.strike(:);
    cap_maturities = flat_vols.maturity(:);
    flat_matrix    = flat_vols.flatVol;
    fwd_libor = spot_vol_parameters.fwd_libor;

    n_strikes = numel(strikes);
    M         = numel(fwd_libor);

    spot_vols_matrix = zeros(M, n_strikes);
    for k = 1:n_strikes
        spot_vols_matrix(:, k) = bootstrap_vol( ...
            flat_matrix(:, k), strikes(k), ...
            spot_vol_parameters,cap_maturities);
    end

end