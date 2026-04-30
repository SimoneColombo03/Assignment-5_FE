function notional_caps = compute_portfolio_hedged_with_cap(output,DV01_cap)

b = [-output.coarse_v(1);-output.coarse_v(2)];

notional_caps = DV01_cap\b;

end