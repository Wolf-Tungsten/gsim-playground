package gsimrepro

import chisel3._
import chisel3.stage.ChiselGeneratorAnnotation
import circt.stage.ChiselStage

class PipeCollapseRepro extends Module {
  val io = IO(new Bundle {
    val in = Input(Bool())
    val a = Output(Bool())
    val b = Output(Bool())
  })

  val aReg = RegInit(false.B)
  val bReg = RegInit(false.B)

  aReg := io.in
  bReg := aReg

  io.a := aReg
  io.b := bReg
}

object PipeCollapseReproMain extends App {
  (new ChiselStage).execute(
    args,
    Seq(ChiselGeneratorAnnotation(() => new PipeCollapseRepro))
  )
}
