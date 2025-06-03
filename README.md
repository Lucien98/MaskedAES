# Masked AES Implementations with Arbitrary Protection Order in Glitch-extended Probing model
## Architecture
We used a modified version of the round-based architecture in [compress_artifact](https://github.com/cassiersg/compress_artifact) (adaptation of input linear mapping of the S-box).

## Source Code Structure
  - aes_hdl_41_noia/: round-based AES Implementations using Hadžić's $GF_2^8$ inverter
  	+ sbox: masked AES S-Box / $GF_2^8$ inverter using Hadžić's decomposition with a latency of three cycles
  - aes_hdl_41_noia/: round-based AES Implementations using Canright's $GF_2^8$ inverter
  	+ sbox: masked AES S-Box / $GF_2^8$ inverter using Canright's decomposition with a latency of four cycles

## Run the testbenchs
You can use verilator to check the correctness of the AES encryption.

First, install `verilator` and `make`.
```bash
sudo apt update
sudo apt install -y verilator make
```

Then run the testbenchs.
```bash
make verilate_41_noia SHARES=2 # check for the 41-cycle AES
make verilate_51_noia SHARES=2 # check for the 51-cycle AES
```
We use the test vector as follows:
 
  - umsk_plaintext: 0x340737e0a29831318d305a88a8f64332
  - umsk_key: 0x3c4fcf098815f7aba6d2ae2816157e2b
  - umsk_ciphertext: 0x320b6a19978511dcfb09dc021d842539

If the process is done correctly, the last line of the above command should be 
```
Recombined ciphertext: 0x320b6a19978511dcfb09dc021d842539
```
## Preparation for Synthesis
To get the area data in the paper, you should install `yosys` and `make`.

```bash
sudo apt update
sudo apt install -y yosys make
```

The version we installed:

 - Yosys 0.33
 - GNU Make 4.3

Before synthesis, create the directories that stores the results.

```bash
make resdir
```

## Synthesis
**Synthesize a module with a specific number of shares**

To synthesize the 3-cycle s-box with 2 shares
```bash
make aes_hdl_41_noia/sbox/aes_sbox SHARES=2
```

**Synthesize S-Box / AES CORE with the number of shares less than 4**

When synthesizing AES S-Box to get the area data, add the parameter "IA_DEF=1" to include the area of input linear mapping of the S-Box.

```bash
make syn_sbox IA_DEF=1 # synthesize S-Box, set IA_DEF=1 to include input linear mapping
make syn_aes_core # synthesize aes core without PRNG
make syn_aes_wrapper # synthesize aes core with PRNG
```


**Get the area data**
```bash
python get_stats.py syn/aes_hdl_51_noia/sbox _Zmul1xDI _Zmul2xDI _Zmul3xDI _Zinv1xDI _Zinv2xDI _Zinv3xDI _BxDI

python get_stats.py syn/aes_hdl_41_noia/sbox RandomZ RandomB

python get_stats.py syn/aes_hdl_51_noia/full_aes/MSKaes_128bits_round_based rnd_bus0w rnd_bus1w rnd_bus2w rnd_bus3w

python get_stats.py syn/aes_hdl_51_noia/full_aes/wrapper_aes128

python get_stats.py syn/aes_hdl_41_noia/full_aes/MSKaes_128bits_round_based RandomZw RandomBw

python get_stats.py syn/aes_hdl_41_noia/full_aes/wrapper_aes128
```

## Data
Area data for three-staged S-Box

Column `#random` lists the required number of random bits. Column `area.wo` lists the real area without RNG. Column `area.w`/`area.w.pred` lists the predicted area with RNG. Column `area.w.real` lists the real area with RNG. 

| #random | area.wo (GE) | area.w (GE) |
|--------|---------|---------|
| 28     | 1626.7  | 2729.9  |
| 84     | 3885    | 7194.6  |
| 156    | 7546    | 13692.4 |
| 250    | 11286.7 | 21136.7 |

Area data for four-staged S-Box

| #random | area.wo (GE) | area.w (GE) |
|--------|---------|---------|
| 24     | 1668    | 2613.6  |
| 72     | 3751.7  | 6588.5  |
| 124    | 6333.3  | 11218.9 |
| 200    | 9466    | 17346   |

Area data for 41-cycle AES

| #random | area.wo (GE) | area.w.pred (GE) | area.w.real (GE) |
|--------|---------|-------------|-------------|
| 560    | 49439.3 | 71503.3     | 70383       |
| 1680   | 102767  | 168959      | 164719.3    |
| 3120   | 182513  | 305441      | 299428.7    |
| 5000   | 269242  | 466242      | 450908.7    |

Area data for 51-cycle AES

| #random | area.wo (GE)  | area.w.pred (GE) | area.w.real (GE) |
|--------|----------|-------------|-------------|
| 480    | 48621.3  | 67533.3     | 67379.7     |
| 1440   | 97831.7  | 154567.7    | 153972.3    |
| 2480   | 153535.7 | 251247.7    | 249809.3    |
| 4000   | 222892   | 380492      | 378035.7    |

## Formal Verification of S-Boxes without input linear mapping

We use maskVerif to verify the security of our constructions for **S-Boxes without input linear mapping**.

### installation of maskVerif:
**Install the Ocaml development environment.**

1. install opam: `sudo apt install opam`
2. initialize the opam environment: `opam init`; when the command outputs "Do you want opam to modify ~/.profile? [N/y/f]", press `y` and enter.
3. update the current shell environment for opam: `eval $(opam env --switch=default)`
4. install ocamlbuild and ocamlfind: `opam install ocamlbuild ocamlfind`
5. install dependencies for maskVerif: `opam install zarith menhirLib ocamlgraph menhir`

**Build maskVerif**
```bash
make mv
```
### Formal verification using maskVerif
The S-Boxes without input linear mapping is $d$-MO-SNI if their output shares are stored in registers, otherwise it is $d$-NI.

To verify $d$-NI, i.e., the outputs shares of the S-Boxes are not stored in registers, run the following:
```bash
make syn_sbox
make benchs NOTION=NI
make fv
```

To verify $d$-MO-SNI, i.e., the outputs shares of the S-Boxes are stored in registers, run the following:
```bash
make syn_sbox FV_DEF=1
make benchs NOTION=SNI
make fv
```


## License
See LICENSE.txt.
