function [price, std_err] = price_exotic_cap_mc(v_bmm, ...
                                spot_vol_parameters, lambda, n_caplets, ...
                                spread, n_paths, drift_sign)

% PRICE_EXOTIC_CAP_MC  Monte Carlo pricing of the exotic cap of Case Study 2.
%
%   Quarterly payoff at T_{i+1} (for i = 1, ..., n_caplets):
%       payoff_i = delta_i * [ L(T_i, T_{i+1}) - L(T_{i-1}, T_i) - spread ]^+
%
%   Each coupon is priced under the T_{i+1}-forward measure, where:
%     * B_new := B(t; T_i, T_{i+1})    -- martingale,        vol = v_bmm(i)
%     * B_prev := B(t; T_{i-1}, T_i)    -- driftful (Girsanov), vol = v_bmm(i-1)
%
%   Under the BMM step-vol convention (vols constant between resets), the
%   joint distribution of (B_prev(T_{i-1}), B_new(T_i)) is exact bivariate
%   lognormal -- no path discretisation needed.
%
%   Correlation: rho = exp(-lambda * delta_i).
%
%   Special case  i = 1:  L(T_0, T_1) is the spot Eur 3m Libor at t_0,
%   already fixed and treated as a constant. Only B_new(T_1) is simulated.
%
%   INPUTS:
%   v_bmm                - [n_caplets x 1] BMM vols at the ATM strike
%   spot_vol_parameters  - struct from compute_caplets_maturities
%   lambda               - decay parameter for correlation (default 0.1)
%   n_caplets            - number of coupons (default 15 for the 4y exotic)
%   spread               - constant subtracted in payoff (default 5e-4)
%   n_paths              - MC paths per coupon (default 1e5)
%   drift_sign           - +1 or -1 (numerically indistinguishable; default +1)
%
%   OUTPUT:
%   price                - exotic cap price per unit notional
%   std_err              - MC standard error

    if nargin < 7 || isempty(drift_sign), drift_sign = +1; end
    if nargin < 6 || isempty(n_paths),    n_paths    = 1e5; end
    if nargin < 5 || isempty(spread),     spread     = 5e-4; end
    if nargin < 4 || isempty(n_caplets),  n_caplets  = 15;  end
    if nargin < 3 || isempty(lambda),     lambda     = 0.1; end

    fwd_libor  = spot_vol_parameters.fwd_libor(:);
    yf_caplets = spot_vol_parameters.yf_between_caplets(:);
    T_expiry   = spot_vol_parameters.T_expiry(:);
    df_caplets = spot_vol_parameters.df_caplets(:);

    % Forward bonds B(0; T_i, T_{i+1}) = 1 / (1 + delta_i * F_i)
    B_fwd0 = 1 ./ (1 + yf_caplets .* fwd_libor);

    % Reset discount: B(0, T_i) = B(0, T_{i+1}) * (1 + delta_i * F_i)
    df_reset = df_caplets .* (1 + yf_caplets .* fwd_libor);

    % Spot 3m Libor at t_0 (the "previous" Libor for the first coupon, i=1)
    %   L(t_0; T_0, T_1) = (1 - B(t_0, T_1)) / (delta_1 * B(t_0, T_1))
    %   B(t_0, T_1) = first element of df_reset
    delta_0  = yf_caplets(1);          % yf(T_0, T_1)
    B_T1     = df_reset(1);
    L_spot_3m = (1 - B_T1) / (delta_0 * B_T1);

    coupon_pv = zeros(n_caplets, 1);
    coupon_se = zeros(n_caplets, 1);

    for i = 1:n_caplets

        delta_i  = yf_caplets(i);          % delta(T_i, T_{i+1})
        T_i      = T_expiry(i);            % time-to-fixing of the new Libor
        Bp_i     = df_caplets(i);          % B(0, T_{i+1})
        v_new    = v_bmm(i);               % vol of B(t; T_i, T_{i+1})
        Bnew_0   = B_fwd0(i);              % forward bond at t = 0

        if i == 1
            % Univariate MC: previous Libor is deterministic
            Z = randn(n_paths, 1);
            log_Bnew = log(Bnew_0) - 0.5 * v_new^2 * T_i + v_new * sqrt(T_i) * Z;
            B_new    = exp(log_Bnew);
            L_new    = (1 - B_new) ./ (delta_i * B_new);

            payoff = max(L_new - L_spot_3m - spread, 0);

            coupon_pv(i) = delta_i * Bp_i * mean(payoff);
            coupon_se(i) = delta_i * Bp_i * std(payoff) / sqrt(n_paths);
            continue
        end

        % i >= 2: bivariate MC
        delta_im1 = yf_caplets(i-1);
        T_im1     = T_expiry(i-1);
        v_prev    = v_bmm(i-1);
        Bprev_0   = B_fwd0(i-1);

        rho = exp(-lambda * delta_i);    % correlation between W_{i-1} and W_i

        Z1 = randn(n_paths, 1);
        Z2 = rho * Z1 + sqrt(1 - rho^2) * randn(n_paths, 1);

        % B_new(T_i): martingale under T_{i+1}-forward
        log_Bnew = log(Bnew_0) - 0.5 * v_new^2 * T_i + v_new * sqrt(T_i) * Z1;

        % B_prev(T_{i-1}): driftful under T_{i+1}-forward
        log_Bprev = log(Bprev_0) ...
                    + drift_sign * rho * v_prev^2 * T_im1 ...
                    - 0.5 * v_prev^2 * T_im1 ...
                    + v_prev * sqrt(T_im1) * Z2;

        B_new  = exp(log_Bnew);
        B_prev = exp(log_Bprev);

        L_new  = (1 - B_new)  ./ (delta_i   * B_new);
        L_prev = (1 - B_prev) ./ (delta_im1 * B_prev);

        payoff = max(L_new - L_prev - spread, 0);

        coupon_pv(i) = delta_i * Bp_i * mean(payoff);
        coupon_se(i) = delta_i * Bp_i * std(payoff) / sqrt(n_paths);
    end

    price   = sum(coupon_pv);
    std_err = sqrt(sum(coupon_se.^2));     % independent MC per coupon
end