function delta_NPV = compute_delta_NPV_swap(ratesSet,dates,discounts, ...
    start_date,coarse)

    bumped_discounts_2y_bucket = coarse.discounts_2y_bucket;
    bumped_discounts_6y_bucket = coarse.discunts_6y_bucket;
    bumped_discounts_10y_bucket = coarse.discounts_10y_bucket;
    
    swap_rate_2y = mean(ratesSet.swaps(2,:),2);
    swap_rate_6y = mean(ratesSet.swaps(6,:),2);
    swap_rate_10y = mean(ratesSet.swaps(10,:),2);
    
    swap_rates = [swap_rate_2y; swap_rate_6y; swap_rate_10y];
    
    bumped_discounts = [bumped_discounts_2y_bucket, bumped_discounts_6y_bucket, bumped_discounts_10y_bucket];
    delta_NPV = zeros(3);
    
    for i = 1:3
        for j = 1:3
        maturity_date_unadj = start_date +datenum(years(2+(i-1)*4));
        maturity_date = business_date_offset(maturity_date_unadj);
        df_base = get_discount_factor_by_zero_rates_linear_interp(start_date,maturity_date,dates,discounts);
        df_bump = get_discount_factor_by_zero_rates_linear_interp(start_date,maturity_date,dates,bumped_discounts(:,j));
        BPV_shifted = BasisPointValueFloating(start_date,maturity_date_unadj,dates,bumped_discounts(:,j));
        BPV_base = BasisPointValueFloating(start_date,maturity_date_unadj,dates,discounts);
        delta_NPV(i,j) = df_bump - df_base + swap_rates(i)*(BPV_shifted-BPV_base);
        end
     end
end

    



    
