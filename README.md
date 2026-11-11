# pgvector Windows Binaries

Precompiled [pgvector](https://github.com/pgvector/pgvector) binaries for **Windows (x64)**, built automatically with GitHub Actions directly from the official upstream source.

Building pgvector on Windows requires Visual Studio Build Tools, `nmake`, and a matching PostgreSQL development setup. This repository does that work for you, so installing the extension takes a minute instead of an afternoon.

> **Unofficial project.** This repository is not affiliated with or endorsed by the pgvector project or the PostgreSQL Global Development Group.

## Supported versions

| PostgreSQL | Architecture | Status |
|:----------:|:------------:|:------:|
| 16         | x64          | ✅      |
| 17         | x64          | ✅      |
| 18         | x64          | ✅      |

Binaries are built against the PostgreSQL distribution installed via Chocolatey (EnterpriseDB builds). They are intended for the standard EDB installer layout (`C:\Program Files\PostgreSQL\<version>`).

## Quick start (recommended)

Run PowerShell **as Administrator**:

```powershell
# 1. Download the installer
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/1Henryc/pgvector-windows-binaries/main/scripts/install-pgvector.ps1" `
  -OutFile install-pgvector.ps1

# 2. Review the script before running it
notepad .\install-pgvector.ps1

# 3. Preview what would happen (no changes made)
.\install-pgvector.ps1 -Version v0.8.7 -PgVersion 17 -WhatIf

# 4. Install
.\install-pgvector.ps1 -Version v0.8.7 -PgVersion 17
```

Then, in your database:

```sql
CREATE EXTENSION vector;
SELECT '[1,2,3]'::vector;
```

### Installer parameters

| Parameter    | Description                                                                 | Default                              |
|--------------|-----------------------------------------------------------------------------|--------------------------------------|
| `-Version`   | Release tag to install (e.g. `v0.8.7`)                                      | `v0.8.7`                             |
| `-PgVersion` | PostgreSQL major version (`16`, `17`, `18`). Required if several are installed | auto-detected if only one is present |
| `-PgRoot`    | Custom PostgreSQL installation path                                         | `C:\Program Files\PostgreSQL\<ver>`  |
| `-Repo`      | Source repository for the release assets                                    | `1Henryc/pgvector-windows-binaries`  |
| `-WhatIf`    | Show what would be installed without changing anything                      | off                                  |

What the installer does:

1. Resolves the target PostgreSQL installation (and refuses to guess if several exist).
2. Downloads the ZIP and `SHA256SUMS.txt` from the GitHub Release.
3. Verifies the ZIP's SHA-256 hash against the entry for that exact file.
4. Validates the archive contents (`vector.dll`, `vector.control`, `vector--*.sql`).
5. Copies the files into the PostgreSQL `lib` and `share\extension` folders.
6. Cleans up all temporary files.

## Manual installation

1. Download `pgvector-<version>-pg<N>-windows-x64.zip` and `SHA256SUMS.txt` from the [Releases](../../releases) page.
2. Verify the checksum (see [Verifying downloads](#verifying-downloads)).
3. Extract the ZIP and copy (as Administrator):
   - `lib\vector.dll` → `<PostgreSQL>\lib`
   - `share\extension\*` → `<PostgreSQL>\share\extension`
4. Run `CREATE EXTENSION vector;` in your database.

Each ZIP also contains an `INSTALL.txt` and the pgvector `LICENSE`.

## Verifying downloads

**PowerShell**

```powershell
(Get-FileHash .\pgvector-v0.8.7-pg17-windows-x64.zip -Algorithm SHA256).Hash.ToLower()
# Compare with the matching line in SHA256SUMS.txt
```

**Linux / macOS / Git Bash**

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

> A checksum published alongside the file protects against corruption and tampering in transit. It does not protect against a compromised release. If you need stronger guarantees, review the workflow and build the binaries yourself (see below).

## Upgrading

1. Stop connections that use the extension, or restart the PostgreSQL service so `vector.dll` is not locked.
2. Run the installer with the new `-Version`.
3. In each database, run:

```sql
ALTER EXTENSION vector UPDATE;
```

## How the binaries are built

Builds are produced by the [`Build and Release Windows Binaries`](.github/workflows/release.yml) workflow:

1. A maintainer triggers it manually (`workflow_dispatch`) with an official pgvector tag.
2. For each PostgreSQL version (16, 17, 18), the workflow:
   - sets up the MSVC x64 toolchain,
   - checks out `pgvector/pgvector` at the requested tag,
   - installs PostgreSQL via Chocolatey,
   - compiles with `nmake /F Makefile.win`,
   - runs a smoke test (`CREATE EXTENSION vector;`),
   - packages the result and generates a SHA-256 checksum.
3. A publish job gathers everything into a GitHub Release with a consolidated `SHA256SUMS.txt`.

Every step is visible in the Actions logs, so you can audit exactly how each release was produced.

### Build it yourself

If you prefer not to trust prebuilt binaries:

1. Fork this repository.
2. Go to **Actions → Build and Release Windows Binaries → Run workflow**.
3. Enter the pgvector tag you want (e.g. `v0.8.7`).
4. Download the artifacts from your fork's Releases page.

## Troubleshooting

| Problem | Likely cause and fix |
|---------|----------------------|
| `Insufficient privileges` / script will not start | Run PowerShell as Administrator. |
| `Multiple PostgreSQL versions found` | Pass `-PgVersion 16`, `17`, or `18`. |
| `Could not overwrite files (vector.dll may be in use)` | Restart the PostgreSQL service (`services.msc`) and retry. |
| `Checksum mismatch` | Do not install. Re-download; if it persists, open an issue. |
| `404` when downloading | That version or PostgreSQL major is not published. Check the [Releases](../../releases) page. |
| `could not load library "vector.dll"` | Missing Microsoft Visual C++ runtime. Install the latest [VC++ Redistributable (x64)](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist). |
| `extension "vector" is not available` | Files were copied to the wrong PostgreSQL folder. Confirm the target version and run `SHOW data_directory;` / check the install path. |

## Security

- The installer runs as Administrator and places a DLL inside your PostgreSQL installation, which is equivalent to running code in the database server. **Always review the script and verify checksums before installing.**
- To report a vulnerability, see [SECURITY.md](SECURITY.md).


## License

pgvector is distributed under the [PostgreSQL License](https://github.com/pgvector/pgvector/blob/master/LICENSE). The license text is included in every release ZIP. The scripts and workflows in this repository are provided under the same terms unless stated otherwise.

## Credits

All credit for pgvector goes to [Andrew Kane](https://github.com/ankane) and the [pgvector contributors](https://github.com/pgvector/pgvector/graphs/contributors). This repository only automates building and distributing Windows binaries.