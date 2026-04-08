#include <cstdint>
#include <cstdio>

#ifdef GSIM
#include "PipeCollapseRepro.h"
using Dut = SPipeCollapseRepro;
#endif

#ifdef VERILATOR
#include "verilated.h"
#include "VPipeCollapseRepro.h"
using Dut = VPipeCollapseRepro;
#endif

namespace {

struct StepCase {
  uint8_t in;
  uint8_t expect_a;
  uint8_t expect_b;
};

void fail(int cycle, uint8_t in, uint8_t got_a, uint8_t got_b, uint8_t expect_a, uint8_t expect_b) {
  std::fprintf(
    stderr,
    "mismatch at cycle %d: in=%u got(a=%u,b=%u) expect(a=%u,b=%u)\n",
    cycle,
    static_cast<unsigned>(in),
    static_cast<unsigned>(got_a),
    static_cast<unsigned>(got_b),
    static_cast<unsigned>(expect_a),
    static_cast<unsigned>(expect_b)
  );
}

#ifdef GSIM
void set_reset(Dut& dut, uint8_t value) {
  dut.set_reset(value);
}

void set_input(Dut& dut, uint8_t value) {
  dut.set_io$$in(value);
}

uint8_t get_a(Dut& dut) {
  return dut.get_io$$a();
}

uint8_t get_b(Dut& dut) {
  return dut.get_io$$b();
}

void cycle(Dut& dut) {
  dut.step();
}
#endif

#ifdef VERILATOR
void set_reset(Dut& dut, uint8_t value) {
  dut.reset = value;
}

void set_input(Dut& dut, uint8_t value) {
  dut.io_in = value;
}

uint8_t get_a(Dut& dut) {
  return dut.io_a;
}

uint8_t get_b(Dut& dut) {
  return dut.io_b;
}

void cycle(Dut& dut) {
  dut.clock = 0;
  dut.eval();
  dut.clock = 1;
  dut.eval();
}
#endif

int run() {
  Dut dut;

  set_input(dut, 0);
  set_reset(dut, 1);
  cycle(dut);
  cycle(dut);
  set_reset(dut, 0);

  const StepCase cases[] = {
    {1, 1, 0},
    {0, 0, 1},
    {0, 0, 0},
  };

  for (int i = 0; i < static_cast<int>(sizeof(cases) / sizeof(cases[0])); ++i) {
    const auto& c = cases[i];
    set_input(dut, c.in);
    cycle(dut);
    const uint8_t got_a = get_a(dut);
    const uint8_t got_b = get_b(dut);
    std::printf(
      "cycle=%d in=%u a=%u b=%u\n",
      i,
      static_cast<unsigned>(c.in),
      static_cast<unsigned>(got_a),
      static_cast<unsigned>(got_b)
    );
    if (got_a != c.expect_a || got_b != c.expect_b) {
      fail(i, c.in, got_a, got_b, c.expect_a, c.expect_b);
      return 1;
    }
  }

  std::puts("PASS");
  return 0;
}

}  // namespace

int main(int argc, char** argv) {
#ifdef VERILATOR
  Verilated::commandArgs(argc, argv);
#endif
  return run();
}
