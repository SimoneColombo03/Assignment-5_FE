function digital_cs_value = compute_digital_call_spread(fwd_libor, T_expiry, df_payment, yf_caplet, ...
                                                        K, epsilon, gap, ...
                                                        spot_vols_matrix, strike_grid, caplet_idx)
% COMPUTE_DIGITAL_CALL_SPREAD - Prices a digital option using Call Spread replication.
%
%
% INPUTS:
%   fwd_libor        - Forward Euribor 3M rate.
%   T_expiry         - Time to fixing (Years, Act/365).
%   df_payment       - Discount factor at payment date.
%   yf_caplet        - Accrual factor (Years, Act/360).
%   K                - Digital strike price.
%   epsilon          - Spread width.
%   gap              - Magnitude of the payoff jump (the "Digital Gap").
%   spot_vols_matrix - Matrix of stripped spot volatilities.
%   strike_grid      - Grid of strikes from market data.
%   caplet_idx       - Index of the specific caplet maturity in the grid.
%
% OUTPUT:
%   digital_cs_value - Present value of the replicated digital component.

    % Define strikes for the replication
    K_low = K;
    K_up  = K + epsilon;

    % Interpolate volatilities for both strikes to capture the volatility skew[cite: 1]
    vol_low = interp1(strike_grid, spot_vols_matrix(caplet_idx,:), K_low, 'spline');
    vol_up  = interp1(strike_grid, spot_vols_matrix(caplet_idx,:), K_up, 'spline');

    % Price Lower Caplet (Black '76)
    d1_L = (log(fwd_libor/K_low) + 0.5*vol_low^2*T_expiry) / (vol_low*sqrt(T_expiry));
    d2_L = d1_L - vol_low*sqrt(T_expiry);
    cap_L = fwd_libor * normcdf(d1_L) - K_low * normcdf(d2_L);

    % Price Upper Caplet (Black '76)
    d1_U = (log(fwd_libor/K_up) + 0.5*vol_up^2*T_expiry) / (vol_up*sqrt(T_expiry));
    d2_U = d1_U - vol_up*sqrt(T_expiry);
    cap_U = fwd_libor * normcdf(d1_U) - K_up * normcdf(d2_U);

    % Numerical replication of the digital payoff
    % Value = (Caplet_Low - Caplet_Up) / epsilon * gap
    digital_unit_value = (cap_L - cap_U) / epsilon;
    digital_cs_value = yf_caplet * df_payment * gap * digital_unit_value;
end