function v_bmm = calibrate_bmm_vols(spot_vols_matrix, strike_grid, ...
                                    spot_vol_parameters, n_caplets)

% CALIBRATE_BMM_VOLS  Caplet-by-caplet calibration of BMM vols v_i to match
% the LMM (Black-Libor) caplet prices implied by the stripped spot-vol
% surface.
%
%   For each caplet i = 1, ..., n_caplets:
%     1) take K_i = F_i(0) (ATM-forward, as required by the assignment);
%     2) interpolate sigma_i^LMM on the strike grid (spline) at K_i;
%     3) compute the LMM caplet price (Black-on-Libor, with delta factor);
%     4) invert (fzero) the BMM caplet price (Black-on-bond) on v_i.
%
%   Both the LMM and BMM prices include the delta day-count factor and the
%   appropriate discount, so they are directly comparable.
%
%   INPUTS:
%   spot_vols_matrix      - [M x n_strikes] LMM spot vols (caplet stripping)
%   strike_grid           - [n_strikes x 1] strikes used in the stripping
%   spot_vol_parameters   - struct from compute_caplets_maturities (length M)
%   n_caplets             - how many caplets to calibrate
%
%   OUTPUT:
%   v_bmm                 - [n_caplets x 1] BMM vols at strike K_i = F_i(0)

    fwd_libor  = spot_vol_parameters.fwd_libor(:);
    yf_caplets = spot_vol_parameters.yf_between_caplets(:);
    T_expiry   = spot_vol_parameters.T_expiry(:);
    df_caplets = spot_vol_parameters.df_caplets(:);

    % Reset discount: B(0, T_i) = B(0, T_{i+1}) * (1 + delta_i * F_i)
    df_reset = df_caplets .* (1 + yf_caplets .* fwd_libor);

    v_bmm = zeros(n_caplets, 1);

    for i = 1:n_caplets

        F  = fwd_libor(i);
        K  = F;                              % ATM forward
        d  = yf_caplets(i);
        T  = T_expiry(i);
        Bp = df_caplets(i);                  % B(0, T_{i+1})
        Br = df_reset(i);                    % B(0, T_i)

        % LMM caplet price at strike K = F (ATM):
        %   Caplet = delta * B(0, T_{i+1}) * [F * Phi(d1) - K * Phi(d2)]
        sigma_LMM = interp1(strike_grid, spot_vols_matrix(i, :), K, 'spline');

        sqrtT = sqrt(T);
        d1L   = ( log(F/K) + 0.5 * sigma_LMM^2 * T ) / ( sigma_LMM * sqrtT );
        d2L   = d1L - sigma_LMM * sqrtT;
        caplet_LMM = d * Bp * ( F * normcdf(d1L) - K * normcdf(d2L) );

        % Invert BMM (Black-bond) for v_i so that BMM price matches LMM price
        residual = @(v) caplet_price_bmm(K, Bp, Br, d, T, v) - caplet_LMM;

        % Initial guess: low-rates approximation
        v0       = sigma_LMM * d * F / (1 + d * F);
        v_bmm(i) = fzero(residual, v0);

    end
end