import assert from 'node:assert/strict';
import { createRateLimiter, isUuid } from '../src/ratelimit';

const l = createRateLimiter();
for (let i = 0; i < 3; i++) assert.ok(l.allow('k', 3, 1000, 0));
assert.ok(!l.allow('k', 3, 1000, 500), 'blocked inside the window');
assert.ok(l.allow('other', 3, 1000, 500), 'keys are independent');
assert.ok(l.allow('k', 3, 1000, 1001), 'allowed after the window');
assert.ok(isUuid('123e4567-e89b-12d3-a456-426614174000'));
assert.ok(!isUuid('x') && !isUuid(5) && !isUuid("1' OR 1=1"));
console.log('PASS: rate limiter + uuid validation');
