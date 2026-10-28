#!/usr/bin/env python3
"""Sign WTAGarouVisuals.jar for ZombieBuddy (ZBS sidecar).

ZombieBuddy verifies `<jar>.zbs` next to the JAR: an Ed25519 signature over
the UTF-8 string  ZBS:<SteamID64>:<lowercase sha256 of the jar>  made with a
key whose 32-byte public half is published as  JavaModZBS:<64 hex>  on the
signer's Steam profile summary (or in ZombieBuddy's authors.json). The signer
SteamID64 must be the Workshop uploader. (ZombieBuddy/doc/ModSigning.md,
ZBSVerifier.java.)

Usage
  python3 tools/sign_jar_zbs.py keygen                 # once; prints the JavaModZBS line
  python3 tools/sign_jar_zbs.py sign  --steamid 7656119XXXXXXXXXX
  python3 tools/sign_jar_zbs.py verify                 # same check ZombieBuddy makes
  python3 tools/sign_jar_zbs.py pubkey                 # print JavaModZBS:<hex> again

Files
  private key   ~/.zbs/wtagarou-ed25519.pem   (NEVER in the repo; --key to override)
  public key    workshop/ZBS_PUBLIC_KEY.txt    (committed; the checker verifies with it)
  sidecar       42/media/java/client/WTAGarouVisuals.jar.zbs  (ships with the jar)
  steam id      workshop/ZBS_STEAMID64.txt     (written by `sign`, reused when --steamid is omitted)

Re-run `sign` after EVERY jar rebuild; a stale sidecar is rejected as tampered.
Needs the `cryptography` package (pip install cryptography) or OpenSSL 3 on PATH.
"""
import argparse, hashlib, os, pathlib, re, shutil, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent.parent
JAR = HERE / "42" / "media" / "java" / "client" / "WTAGarouVisuals.jar"
PUB_FILE = HERE / "workshop" / "ZBS_PUBLIC_KEY.txt"
SID_FILE = HERE / "workshop" / "ZBS_STEAMID64.txt"
DEFAULT_KEY = pathlib.Path.home() / ".zbs" / "wtagarou-ed25519.pem"

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
    from cryptography.hazmat.primitives import serialization
    HAVE_CRYPTO = True
except Exception:  # pragma: no cover - depends on the machine
    HAVE_CRYPTO = False


def sha256_hex(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical(steamid, jar_sha):
    return f"ZBS:{steamid}:{jar_sha.lower()}".encode("utf-8")


def openssl():
    exe = shutil.which("openssl")
    if not exe:
        sys.exit("need the python 'cryptography' package (pip install cryptography) or openssl on PATH")
    return exe


# -- key handling -------------------------------------------------------------

def keygen(key_path):
    key_path = pathlib.Path(key_path)
    if key_path.exists():
        sys.exit(f"refusing to overwrite existing key {key_path}")
    key_path.parent.mkdir(parents=True, exist_ok=True)
    if HAVE_CRYPTO:
        priv = Ed25519PrivateKey.generate()
        pem = priv.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                 serialization.NoEncryption())
        key_path.write_bytes(pem)
    else:
        subprocess.run([openssl(), "genpkey", "-algorithm", "ed25519", "-out", str(key_path)], check=True)
    try:
        os.chmod(key_path, 0o600)
    except Exception:
        pass
    return key_path


def public_hex(key_path):
    key_path = pathlib.Path(key_path)
    if not key_path.exists():
        sys.exit(f"private key not found: {key_path} (run: sign_jar_zbs.py keygen)")
    if HAVE_CRYPTO:
        priv = serialization.load_pem_private_key(key_path.read_bytes(), password=None)
        raw = priv.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
        return raw.hex()
    der = subprocess.run([openssl(), "pkey", "-in", str(key_path), "-pubout", "-outform", "DER"],
                         check=True, capture_output=True).stdout
    return der[-32:].hex()          # SubjectPublicKeyInfo: the raw key is the last 32 bytes


def sign_bytes(key_path, msg):
    if HAVE_CRYPTO:
        priv = serialization.load_pem_private_key(pathlib.Path(key_path).read_bytes(), password=None)
        return priv.sign(msg)
    with tempfile.TemporaryDirectory() as td:
        m = pathlib.Path(td) / "msg"; m.write_bytes(msg)
        return subprocess.run([openssl(), "pkeyutl", "-sign", "-rawin", "-inkey", str(key_path), "-in", str(m)],
                              check=True, capture_output=True).stdout


def verify_bytes(pub_hex, msg, sig):
    pub = bytes.fromhex(pub_hex)
    if len(pub) != 32:
        return False
    if HAVE_CRYPTO:
        try:
            Ed25519PublicKey.from_public_bytes(pub).verify(sig, msg)
            return True
        except Exception:
            return False
    # SubjectPublicKeyInfo prefix for Ed25519 (RFC 8410)
    spki = bytes.fromhex("302a300506032b6570032100") + pub
    with tempfile.TemporaryDirectory() as td:
        d = pathlib.Path(td)
        (d / "pub.der").write_bytes(spki); (d / "msg").write_bytes(msg); (d / "sig").write_bytes(sig)
        r = subprocess.run([openssl(), "pkeyutl", "-verify", "-rawin", "-pubin", "-inkey", str(d / "pub.der"),
                            "-keyform", "DER", "-in", str(d / "msg"), "-sigfile", str(d / "sig")],
                           capture_output=True)
        return r.returncode == 0


# -- sidecar ------------------------------------------------------------------

SID_RE = re.compile(r"^SteamID64:(\d{17})$")
SIG_RE = re.compile(r"^Signature:([0-9a-fA-F]{128})$")


def write_sidecar(jar, steamid, key_path):
    sig = sign_bytes(key_path, canonical(steamid, sha256_hex(jar)))
    zbs = pathlib.Path(str(jar) + ".zbs")
    zbs.write_text(f"ZBS\nSteamID64:{steamid}\nSignature:{sig.hex()}\n", encoding="utf-8", newline="\n")
    return zbs


def parse_sidecar(zbs):
    lines = [l.strip() for l in pathlib.Path(zbs).read_text(encoding="utf-8").splitlines()]
    if len(lines) < 3 or lines[0] != "ZBS":
        raise ValueError("first line must be ZBS")
    m2, m3 = SID_RE.match(lines[1]), SIG_RE.match(lines[2])
    if not m2:
        raise ValueError("second line must be SteamID64:<17 digits>")
    if not m3:
        raise ValueError("third line must be Signature:<128 hex>")
    return m2.group(1), bytes.fromhex(m3.group(1))


def verify_sidecar(jar, pub_hex):
    """Mirror of ZBSVerifier: (ok, message)."""
    zbs = pathlib.Path(str(jar) + ".zbs")
    if not zbs.exists():
        return False, f"missing {zbs.name} (mod would load as UNSIGNED)"
    try:
        steamid, sig = parse_sidecar(zbs)
    except ValueError as e:
        return False, f"malformed {zbs.name}: {e}"
    if verify_bytes(pub_hex, canonical(steamid, sha256_hex(jar)), sig):
        return True, f"{zbs.name} valid for SteamID64 {steamid}, jar sha256 {sha256_hex(jar)[:16]}..."
    return False, f"{zbs.name} does NOT match this jar (rebuilt after signing?) or the public key"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["keygen", "sign", "verify", "pubkey"])
    ap.add_argument("--key", default=str(DEFAULT_KEY), help="private key PEM (default ~/.zbs/wtagarou-ed25519.pem)")
    ap.add_argument("--steamid", help="signer SteamID64 (17 digits) = the Workshop uploader")
    ap.add_argument("--jar", default=str(JAR))
    a = ap.parse_args()
    jar = pathlib.Path(a.jar)

    if a.command == "keygen":
        p = keygen(a.key)
        hexkey = public_hex(p)
        PUB_FILE.parent.mkdir(parents=True, exist_ok=True)
        PUB_FILE.write_text(hexkey + "\n", encoding="utf-8")
        print(f"private key written to {p}  (keep it out of the repo; back it up)")
        print(f"public key written to {PUB_FILE.relative_to(HERE)}")
        print(f"Add this line to your Steam profile summary:\n  JavaModZBS:{hexkey}")
        return

    if a.command == "pubkey":
        print(f"JavaModZBS:{public_hex(a.key)}")
        return

    if a.command == "sign":
        if not jar.exists():
            sys.exit(f"jar not found: {jar}")
        steamid = a.steamid or (SID_FILE.read_text().strip() if SID_FILE.exists() else None)
        if not steamid or not re.fullmatch(r"\d{17}", steamid):
            sys.exit("--steamid must be your 17-digit SteamID64 (Steam > profile > Edit Profile > the number in the URL, or steamid.io)")
        hexkey = public_hex(a.key)
        PUB_FILE.write_text(hexkey + "\n", encoding="utf-8")
        SID_FILE.write_text(steamid + "\n", encoding="utf-8")
        zbs = write_sidecar(jar, steamid, a.key)
        ok, msg = verify_sidecar(jar, hexkey)
        print(("ok    " if ok else "FAIL  ") + msg)
        print(f"wrote {zbs.relative_to(HERE)}; profile line: JavaModZBS:{hexkey}")
        sys.exit(0 if ok else 1)

    if a.command == "verify":
        if not PUB_FILE.exists():
            sys.exit(f"{PUB_FILE} missing; run keygen/sign first")
        ok, msg = verify_sidecar(jar, PUB_FILE.read_text().strip())
        print(("ok    " if ok else "FAIL  ") + msg)
        sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
