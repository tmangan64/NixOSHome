package nixgen.crypto;

/**
 * Bech32 encoding/decoding for age keys.
 * Based on BIP-0173 specification.
 */
public class Bech32 {
    private static final String CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";
    private static final int[] GENERATOR = {0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3};

    /**
     * Encode data as bech32 with given human-readable prefix.
     */
    public static String encode(String hrp, byte[] data) {
        byte[] values = convertBits(data, 8, 5, true);
        byte[] checksum = createChecksum(hrp, values);

        StringBuilder result = new StringBuilder(hrp);
        for (byte v : values) {
            result.append(CHARSET.charAt(v));
        }
        for (byte c : checksum) {
            result.append(CHARSET.charAt(c));
        }
        return result.toString();
    }

    /**
     * Decode bech32 string, returning the data portion.
     */
    public static byte[] decode(String hrp, String bech32) {
        if (!bech32.startsWith(hrp)) {
            throw new IllegalArgumentException("Invalid HRP");
        }

        String data = bech32.substring(hrp.length());
        byte[] values = new byte[data.length()];
        for (int i = 0; i < data.length(); i++) {
            int idx = CHARSET.indexOf(data.charAt(i));
            if (idx < 0) {
                throw new IllegalArgumentException("Invalid character in bech32");
            }
            values[i] = (byte) idx;
        }

        // Remove checksum (last 6 characters)
        byte[] dataValues = new byte[values.length - 6];
        System.arraycopy(values, 0, dataValues, 0, dataValues.length);

        return convertBits(dataValues, 5, 8, false);
    }

    private static int polymod(byte[] values) {
        int chk = 1;
        for (byte v : values) {
            int top = chk >> 25;
            chk = ((chk & 0x1ffffff) << 5) ^ v;
            for (int i = 0; i < 5; i++) {
                if (((top >> i) & 1) == 1) {
                    chk ^= GENERATOR[i];
                }
            }
        }
        return chk;
    }

    private static byte[] hrpExpand(String hrp) {
        byte[] result = new byte[hrp.length() * 2 + 1];
        for (int i = 0; i < hrp.length(); i++) {
            result[i] = (byte) (hrp.charAt(i) >> 5);
            result[hrp.length() + 1 + i] = (byte) (hrp.charAt(i) & 31);
        }
        result[hrp.length()] = 0;
        return result;
    }

    private static byte[] createChecksum(String hrp, byte[] data) {
        byte[] hrpExp = hrpExpand(hrp);
        byte[] values = new byte[hrpExp.length + data.length + 6];
        System.arraycopy(hrpExp, 0, values, 0, hrpExp.length);
        System.arraycopy(data, 0, values, hrpExp.length, data.length);

        int polymod = polymod(values) ^ 1;
        byte[] checksum = new byte[6];
        for (int i = 0; i < 6; i++) {
            checksum[i] = (byte) ((polymod >> (5 * (5 - i))) & 31);
        }
        return checksum;
    }

    private static byte[] convertBits(byte[] data, int fromBits, int toBits, boolean pad) {
        int acc = 0;
        int bits = 0;
        int maxv = (1 << toBits) - 1;
        java.util.List<Byte> result = new java.util.ArrayList<>();

        for (byte b : data) {
            int value = b & 0xff;
            acc = (acc << fromBits) | value;
            bits += fromBits;
            while (bits >= toBits) {
                bits -= toBits;
                result.add((byte) ((acc >> bits) & maxv));
            }
        }

        if (pad && bits > 0) {
            result.add((byte) ((acc << (toBits - bits)) & maxv));
        }

        byte[] ret = new byte[result.size()];
        for (int i = 0; i < result.size(); i++) {
            ret[i] = result.get(i);
        }
        return ret;
    }
}
