function  output = coarse_vega(dates, discounts, flat_vols, notional, ...
                                   start_date, maturity_date_unadj, ...
                                   first_coupon_rate, mode_after_6y, ...
                                   spot_vol_parameters, X_base)
bump = 1e-2;
output = struct();
coarse_v = zeros(2,1);
     mat_vol = flat_vols.maturity;  
     weights = triangular_weights_vega(mat_vol);
    for i=1:2
        flat_vols_bumped         = flat_vols;
        flat_vols_bumped.flatVol = flat_vols.flatVol + bump*repmat(weights(:,i),1,size(flat_vols.flatVol,2));
       
        % Re-strip caplet spot vols on the bumped surface
        spot_vols_matrix_bumped = compute_spot_vols_Eur_3m( ...
            flat_vols_bumped, spot_vol_parameters);
        if i==1
            output.spot_vols_bump_b1 = spot_vols_matrix_bumped;
        else
            output.spot_vols_bump_b2 =spot_vols_matrix_bumped;
        end
        % Re-price the bond with the bumped vols (curve unchanged)
        X_bumped = compute_upfront(notional, ...
                                   spot_vols_matrix_bumped, flat_vols.strike(:), ...
                                   spot_vol_parameters, ...
                                   dates, discounts, ...
                                   start_date, maturity_date_unadj, ...
                                   first_coupon_rate, mode_after_6y);
        
        % MTM change for Bank XX (locked X*N, fair X moves)
        coarse_v(i) = -(X_bumped - X_base) * notional;
    end
output.coarse_v = coarse_v;
end


function W = triangular_weights_vega(yf)
% Return [n x 2] of triangular/ramp weights per the convention above.
    yf = yf(:);
    n  = numel(yf);
    W  = zeros(n, 2);

    % Bucket 1: 0-6y -- flat 1 then ramp down to 0 at 6y
    W(:, 1)        = max(0, min(1, (10 - yf) / 4));
    W(yf <= 6, 1)  = 1;

    % Bucket 3: 6-10y -- ramp up from 6y to 10y, then flat 1
    W(:, 2)        = max(0, min(1, (yf - 6) / 4));
    W(yf >= 10, 2) = 1;
end