function notional_caps = compute_portfolio_hedged_with_cap(output, DV01_cap)

% COMPUTE_PORTFOLIO_HEDGED_WITH_CAP  Cap notionals that neutralise the
% bucketed vega of the structured bond (point f).
%
%   Solves the 2x2 linear system
%
%       DV01_cap * [N_6y; N_10y] = -coarse_v
%
%   so that the residual vega is zero in both buckets (0-6y, 6-10y).
%   Positive notionals mean Bank XX BUYS the corresponding ATM cap.
%
%   INPUTS:
%   output    - struct from coarse_vega; field .coarse_v (2x1) is the
%               bond vega per bucket from Bank XX's side
%   DV01_cap  - 2x2 matrix from compute_delta_NPV_cap
%                 rows    = vega bucket   (1 = 0-6y, 2 = 6-10y)
%                 columns = hedging cap    (1 = 6y cap, 2 = 10y cap)
%
%   OUTPUT:
%   notional_caps - [N_6y; N_10y] in EUR

    % We hedge AGAINST the bond's vega, hence the minus sign.
    b = [ -output.coarse_v(1);
          -output.coarse_v(2) ];

    notional_caps = DV01_cap \ b;

end