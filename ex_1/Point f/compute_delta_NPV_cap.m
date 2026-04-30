function DV01_cap = compute_delta_NPV_cap(flat_vols,ratesSet,spot_vols_matrix,output,dates, discounts)

strike_6y = mean(ratesSet.swaps(6,:),2);
strike_10y = mean(ratesSet.swaps(10,:),2);

parameters_caplets = compute_caplets_maturities(flat_vols, dates, discounts);
idx_6 = find (flat_vols.maturity==6);
idx_10 = find (flat_vols.maturity==10);
price_cap_base_6y = cap_increment_price(flat_vols,spot_vols_matrix(idx_6,:),strike_6y,parameters_caplets);
price_cap_base_10y = cap_increment_price(flat_vols,spot_vols_matrix(idx_10,:),strike_10y,parameters_caplets);

price_cap_1b_6y = cap_increment_price(flat_vols,output.spot_vols_bump_b1(idx_6,:),strike_6y,parameters_caplets);
price_cap_1b_10y = cap_increment_price(flat_vols,output.spot_vols_bump_b1(idx_10,:),strike_10y,parameters_caplets);
price_cap_2b_6y = cap_increment_price(flat_vols,output.spot_vols_bump_b2(idx_6,:),strike_6y,parameters_caplets);
price_cap_2b_10y = cap_increment_price(flat_vols,output.spot_vols_bump_b2(idx_10,:),strike_10y,parameters_caplets);

DV01_cap(1,1) = price_cap_1b_6y - price_cap_base_6y; 
DV01_cap(1,2) =  price_cap_2b_6y - price_cap_base_6y; 
DV01_cap(2,1) = price_cap_1b_10y - price_cap_base_10y;
DV01_cap(1,1) = price_cap_2b_10y - price_cap_base_10y;

end
function p = cap_increment_price(flat_vols,spot_vols,strike_cap, parameters_caplets)
    fwd = parameters_caplets.fwd_libor;
    r = parameters_caplets.r_eff;
    yf = parameters_caplets.yf_between_caplets;
    T = parameters_caplets.T_expiry;

    sigma_caplets = interp1(flat_vols.strike, spot_vols,strike_cap,'spline');

    caplet_prices = blkprice(fwd, strike_cap, r, T, sigma_caplets );
    p = sum( yf .* caplet_prices );
end