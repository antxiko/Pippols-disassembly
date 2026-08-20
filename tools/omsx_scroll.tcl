# Cuanto cuesta el scroll al pixel, medido en el emulador.
#
#   PIP_OUT=<dir> PIP_SEG=<segundos> openmsx -machine Philips_VG_8020 \
#       -cart pippols.rom -script tools/omsx_scroll.tcl
#
# Mide, con el reloj emulado, tres cosas de cada fotograma de la demo (que
# juega sola, asi que no hace falta tocar nada):
#   - lo que tarda VUELCA_NOMBRES (0x5312 -> el `ret` de 0x5383)
#   - lo que tarda la interrupcion entera (0x4010 -> el `ret` de 0x402F)
#   - cuantas escrituras al puerto de datos del VDP (0x98) hay por fotograma
# El resultado va a <dir>/scroll.log en ciclos del Z80 (3579545 Hz).

set OUT [expr {[info exists ::env(PIP_OUT)] ? $::env(PIP_OUT) : "work/omsx"}]
set SEG [expr {[info exists ::env(PIP_SEG)] ? $::env(PIP_SEG) : 90}]
file mkdir $OUT
set LOG [open "$OUT/scroll.log" w]
proc say {m} { global LOG; puts $LOG $m; flush $LOG }
set throttle off

set HZ 3579545.0
set ::t_nombres 0.0
set ::n_nombres 0
set ::sum_nombres 0.0
set ::max_nombres 0.0
set ::t_int 0.0
set ::n_int 0
set ::sum_int 0.0
set ::max_int 0.0
set ::escrituras 0
set ::esc_frame 0
set ::n_esc 0
set ::sum_esc 0
set ::armado 0
set ::hubo_scroll 0
set ::sum_int_j 0.0
set ::max_int_j 0.0
set ::n_int_j 0
set ::sum_esc_j 0
for {set i 0} {$i < 11} {incr i} {set ::hist($i) 0}
set ::hubo_arma 0
set ::n_arma 0

say "# Pippols: coste del scroll al pixel"
say "# maquina [machine_info config_name], reloj $HZ Hz"

debug set_bp 0x404A {} {
    if {!$::armado} {
        set ::armado 1
        # VUELCA_NOMBRES
        debug set_bp 0x5312 {} {set ::t_nombres [machine_info time]; set ::hubo_scroll 1}
        debug set_bp 0x5383 {} {
            set dt [expr {[machine_info time] - $::t_nombres}]
            if {$dt > 0 && $dt < 0.05} {
                set ::sum_nombres [expr {$::sum_nombres + $dt}]
                if {$dt > $::max_nombres} {set ::max_nombres $dt}
                incr ::n_nombres
            }
        }
        # la interrupcion entera
        debug set_bp 0x4010 {} {
            set ::t_int [machine_info time]
            set ::esc_frame 0
            set ::hubo_scroll 0
            set ::hubo_arma 0
        }
        debug set_bp 0x402F {} {
            set dt [expr {[machine_info time] - $::t_int}]
            if {$dt > 0 && $dt < 0.05} {
                set ::sum_int [expr {$::sum_int + $dt}]
                if {$dt > $::max_int} {set ::max_int $dt}
                incr ::n_int
                if {$::esc_frame > 0} {
                    set ::sum_esc [expr {$::sum_esc + $::esc_frame}]
                    incr ::n_esc
                }
                if {$::hubo_scroll} {
                    set ::sum_int_j [expr {$::sum_int_j + $dt}]
                    set ::sum_esc_j [expr {$::sum_esc_j + $::esc_frame}]
                    if {$dt > $::max_int_j} {set ::max_int_j $dt}
                    incr ::n_int_j
                    set b [expr {int($dt * 50.0 * 10.0)}]
                    if {$b > 10} {set b 10}
                    incr ::hist($b)
                    if {$::hubo_arma} {incr ::n_arma}
                }
            }
        }
        # escrituras al puerto de datos del VDP
        debug set_bp 0x5384 {} {set ::hubo_arma 1}
        debug set_watchpoint write_io 0x98 {} {incr ::esc_frame}
    }
}

proc fin {} {
    global HZ
    say ""
    say "VUELCA_NOMBRES (0x5312): [set ::n_nombres] llamadas"
    if {$::n_nombres > 0} {
        say [format "  media  %.0f ciclos" [expr {$::sum_nombres / $::n_nombres * $HZ}]]
        say [format "  maximo %.0f ciclos" [expr {$::max_nombres * $HZ}]]
    }
    say "INTERRUPCION (0x4010): [set ::n_int] fotogramas"
    if {$::n_int > 0} {
        say [format "  media  %.0f ciclos" [expr {$::sum_int / $::n_int * $HZ}]]
        say [format "  maximo %.0f ciclos" [expr {$::max_int * $HZ}]]
        say [format "  el fotograma PAL son %.0f ciclos" [expr {$HZ / 50.0}]]
        say [format "  o sea el %.1f %% del fotograma de media" \
                 [expr {$::sum_int / $::n_int * 50.0 * 100.0}]]
    }
    say "FOTOGRAMAS JUGANDO (los que llaman a VUELCA_NOMBRES): [set ::n_int_j]"
    if {$::n_int_j > 0} {
        say [format "  interrupcion, media  %.0f ciclos (%.1f %% del fotograma)"                  [expr {$::sum_int_j / $::n_int_j * $HZ}] [expr {$::sum_int_j / $::n_int_j * 50.0 * 100.0}]]
        say [format "  interrupcion, maximo %.0f ciclos (%.1f %%)"                  [expr {$::max_int_j * $HZ}] [expr {$::max_int_j * 50.0 * 100.0}]]
        say [format "  escrituras al 0x98:  %.1f por fotograma" [expr {double($::sum_esc_j) / $::n_int_j}]]
        say [format "  y VUELCA_NOMBRES se lleva el %.1f %% de la interrupcion"                  [expr {($::sum_nombres / $::n_nombres) / ($::sum_int_j / $::n_int_j) * 100.0}]]
    }
    if {$::n_int_j > 0} {
        say "  reparto de los fotogramas jugando, por decimas de fotograma:"
        for {set i 0} {$i < 11} {incr i} {
            if {$::hist($i) > 0} {
                say [format "    %3d-%3d %% : %5d fotogramas" [expr {$i*10}] [expr {$i*10+10}] $::hist($i)]
            }
        }
        say "  de ellos, [set ::n_arma] arman ademas las 24 filas de golpe (cambio de pantalla)"
    }
    if {$::n_esc > 0} {
        say [format "ESCRITURAS AL PUERTO 0x98: %.1f por fotograma (%d fotogramas)" \
                 [expr {double($::sum_esc) / $::n_esc}] $::n_esc]
    }
    close $::LOG
    exit
}
after time $SEG fin
