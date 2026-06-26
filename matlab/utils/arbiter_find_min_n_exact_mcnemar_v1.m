function minN = arbiter_find_min_n_exact_mcnemar_v1(p10, p01, alphaOneSided, targetPower, nMax)
%ARBITER_FIND_MIN_N_EXACT_MCNEMAR_V1 Find smallest N reaching target power.
arguments
    p10 (1,1) double {mustBeGreaterThanOrEqual(p10,0), mustBeLessThan(p10,1)}
    p01 (1,1) double {mustBeGreaterThanOrEqual(p01,0), mustBeLessThan(p01,1)}
    alphaOneSided (1,1) double {mustBeGreaterThan(alphaOneSided,0), mustBeLessThan(alphaOneSided,1)}
    targetPower (1,1) double {mustBeGreaterThan(targetPower,0), mustBeLessThan(targetPower,1)}
    nMax (1,1) double {mustBeInteger, mustBePositive}
end

minN = NaN;
for n = 2:nMax
    powN = arbiter_exact_mcnemar_power_v1(n, p10, p01, alphaOneSided);
    if powN >= targetPower
        minN = n;
        return;
    end
end

warning('arbiter_find_min_n_exact_mcnemar_v1:TargetNotReached', ...
    'Target power %.3f not reached up to nMax=%d.', targetPower, nMax);
end
