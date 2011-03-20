
var crypto = require('crypto');

function keyex(m_exchange, k_shared, algorithm) {
    // Default algorithm is sha256
    algorithm = algorithm || 'sha256';
    var format = 'hex';

    // Compute the signing key
    var hmac = crypto.createHmac(algorithm, k_shared);
    hmac.update(m_exchange);
    var k_sign = hmac.digest(format);

    // Compute the message signature
    hmac = crypto.createHmac(algorithm, k_sign);
    hmac.update(m_exchange);
    var s_exchange = hmac.digest(format);

    // Operation Complete!
    return {k_sign: k_sign, s_exchange: s_exchange};
}

module.exports = keyex;
