function notional_swaps = compute_portfolio_hedged_with_swap(coarse,delta_NPV)

b = [-coarse.DV01(1);-coarse.DV01(2);-coarse.DV01(3)];

notional_swaps = delta_NPV\b;

end