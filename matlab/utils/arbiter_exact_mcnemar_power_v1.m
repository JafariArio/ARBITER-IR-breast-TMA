function powerVal = arbiter_exact_mcnemar_power_v1(nTotal, p10, p01, alphaOneSided)
%ARBITER_EXACT_MCNEMAR_POWER_V1 Exact one-sided McNemar power.
%
% nTotal        : total paired cores
% p10           : P(comparator cancer-like, ARBITER non-cancer)
% p01           : P(comparator non-cancer, ARBITER cancer-like)
% alphaOneSided : one-sided alpha for the exact McNemar test
%
% The rejection region is built conditionally for each discordant total D
% using X ~ Binomial(D, 0.5) under H0, where X is the number of beneficial
% discordances in favor of ARBITER.

arguments
    nTotal (1,1) double {mustBeInteger, mustBePositive}
    p10 (1,1) double {mustBeGreaterThanOrEqual(p10,0), mustBeLessThan(p10,1)}
    p01 (1,1) double {mustBeGreaterThanOrEqual(p01,0), mustBeLessThan(p01,1)}
    alphaOneSided (1,1) double {mustBeGreaterThan(alphaOneSided,0), mustBeLessThan(alphaOneSided,1)}
end

if (p10 + p01) >= 1
    error('arbiter_exact_mcnemar_power_v1:InvalidProbabilities', ...
        'p10 + p01 must be strictly less than 1.');
end

p00 = 1 - p10 - p01;
powerVal = 0;

for x = 0:nTotal
    for y = 0:(nTotal - x)
        d = x + y;
        if d == 0
            continue;
        end

        tailP = 0;
        for k = x:d
            tailP = tailP + nchoosek(d, k) * (0.5 ^ d);
        end

        if tailP <= alphaOneSided
            logProbXY = gammaln(nTotal + 1) - gammaln(x + 1) - gammaln(y + 1) - gammaln(nTotal - x - y + 1) ...
                + x * log(max(p10, realmin)) + y * log(max(p01, realmin)) + (nTotal - x - y) * log(max(p00, realmin));
            probXY = exp(logProbXY);
            powerVal = powerVal + probXY;
        end
    end
end
end
