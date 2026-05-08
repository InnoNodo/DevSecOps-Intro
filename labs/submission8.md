# Lab 8 Submission - Signing, Verification, and Attestations

## Task 1 - Local Registry, Signing, and Verification

### Scope and Evidence

Target image: `bkimminich/juice-shop:v19.0.0` pushed to local registry as `localhost:5000/juice-shop:v19.0.0`.

Evidence files:

- `labs/lab8/analysis/ref.txt`
- `labs/lab8/analysis/ref-after-tamper.txt`
- `labs/lab8/registry/push-original.txt`
- `labs/lab8/registry/push-tampered.txt`
- `labs/lab8/signing/sign-image.txt`
- `labs/lab8/signing/verify-image.txt`
- `labs/lab8/signing/verify-after-tamper.txt`
- `labs/lab8/signing/verify-original-after-tamper.txt`
- `labs/lab8/signing/cosign.pub`

Private key file `labs/lab8/signing/cosign.key` was intentionally not added to git.

Cosign version used: v3.0.6. Because Cosign v3 rejects the old `--tlog-upload=false` flag, I used `labs/lab8/signing/signing-config-no-tlog.json`, a local signing config with no transparency log services. Verification used `--insecure-ignore-tlog`, which is appropriate only for this local registry lab.

### Digest Reference

Original signed reference:

```text
localhost:5000/juice-shop@sha256:b029fa83327aa8a3bbcaf161af6269c18c80134942437cb90794233502554e48
```

Verification succeeded against the public key. The Cosign claim included the same subject digest:

```text
sha256:b029fa83327aa8a3bbcaf161af6269c18c80134942437cb90794233502554e48
```

### Tamper Demonstration

I overwrote the mutable tag `localhost:5000/juice-shop:v19.0.0` with `busybox:latest`. The tag then resolved to a different digest:

```text
localhost:5000/juice-shop@sha256:11f85134f388cff5f4c66f9bb4c5942249c1f6f7eb8b3889948d953487b5f7a8
```

Verification of the tampered digest failed with:

```text
Error: no signatures found
```

Verification of the original digest still succeeded after tag tampering. This demonstrates why signing and verifying by digest protects supply chain integrity: a tag is mutable, but the subject digest identifies the exact manifest content that was signed.

## Task 2 - SBOM Attestation

### Evidence

- `labs/lab8/attest/juice-shop.generated.cdx.json`
- `labs/lab8/attest/syft-generate.log`
- `labs/lab8/attest/attest-sbom.txt`
- `labs/lab8/attest/verify-sbom-attestation.txt`
- `labs/lab8/attest/provenance.json`
- `labs/lab8/attest/attest-provenance.txt`

A CycloneDX SBOM was generated with Syft from a local Docker image archive. The SBOM contains **3533 components**, uses `bomFormat: CycloneDX`, and `specVersion: 1.6`.

The SBOM attestation was attached to the signed image and verified successfully with the Cosign public key. The attestation payload is an in-toto statement whose subject is the image digest and whose predicate type is CycloneDX.

Provenance JSON was generated in `labs/lab8/attest/provenance.json`, but attaching the provenance attestation was interrupted by intermittent local registry timeouts. The accepted attestation evidence for this lab is the verified SBOM attestation.

### Attestations vs Signatures

A signature proves that a signer approved a specific artifact digest. It answers: "Was this exact image signed by the holder of this key?"

An attestation attaches signed metadata about the artifact. It answers richer questions, such as what packages are in the image, how it was built, who built it, or what policy checks passed.

### SBOM Attestation Contents

The SBOM attestation contains package inventory metadata for the Juice Shop image, including component names, versions, package types, package URLs, and CycloneDX metadata. This supports vulnerability management, license review, and incident response when a vulnerable package is announced.

### Provenance Value

A provenance attestation records build context: builder identity, build type, input parameters, timestamps, and completeness metadata. In production, provenance helps verify that an image came from the expected CI/CD process rather than from an untrusted manual build.

## Task 3 - Artifact Signing

### Evidence

- `labs/lab8/artifacts/sample.txt`
- `labs/lab8/artifacts/sample.tar.gz`
- `labs/lab8/artifacts/sample.tar.gz.bundle`
- `labs/lab8/artifacts/sign-blob.txt`
- `labs/lab8/artifacts/verify-blob.txt`

The non-container artifact `sample.tar.gz` was signed with `cosign sign-blob` and verified with `cosign verify-blob`. Verification output:

```text
Verified OK
```

### Use Cases for Blob Signing

Blob signing is useful for release binaries, CLI tools, generated configuration bundles, SBOM files, policy bundles, and deployment manifests. It gives consumers a way to verify artifact integrity even when the artifact is not an OCI image.

### Blob Signing vs Image Signing

Image signing stores signatures as OCI artifacts associated with an image digest in a registry. Blob signing signs an ordinary file directly and stores verification material in a local bundle or detached signature. Image signing is registry-native; blob signing is file-native.

## Notes

The local registry was run with host networking because Docker port forwarding in this WSL environment intermittently timed out on `localhost:5000`. Proxy environment variables were unset for local Cosign operations to avoid routing local registry traffic through the configured HTTP proxy.
