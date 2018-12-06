package main

import "syscall"
import "os"
import "fmt"
import "os/exec"

func main() {
    if os.Getenv("GRAPHICS_INITIALIZED") != "1" {
        fmt.Println("Granting qemu permissions to /dev/dri/renderD128")
        cmd := exec.Command("/usr/bin/setfacl", "-m", "u:qemu:rw", "/dev/dri/renderD128")
        cmdOut, err := cmd.Output()

        fmt.Println(string(cmdOut))

        if err != nil {
            panic(err)
        }

	// Inspired by https://www.redhat.com/archives/libvir-list/2017-March/msg01475.html;
	// to be verified.
        fmt.Println("Granting qemu permissions to /dev/vfio/vfio")
        cmd = exec.Command("/usr/bin/setfacl", "-m", "u:qemu:rw", "/dev/vfio/vfio")
        cmdOut, err = cmd.Output()

        fmt.Println(string(cmdOut))

        if err != nil {
            panic(err)
        }

        fmt.Println("Granting qemu permissions to /dev/vfio/9")
        cmd = exec.Command("/usr/bin/setfacl", "-m", "u:qemu:rw", "/dev/vfio/9")
        cmdOut, err = cmd.Output()

        fmt.Println(string(cmdOut))

        if err != nil {
            panic(err)
        }

        os.Setenv("GRAPHICS_INITIALIZED", "1")
    } else {
        fmt.Println("Skipping graphics initialization")
    }

    fmt.Print("Starting the virt-launcher wrapper\n")

    args := os.Args
    env := os.Environ()
    binary := "/usr/bin/upstream-virt-launcher"

    execErr := syscall.Exec(binary, args, env)
    if execErr != nil {
        panic(execErr)
    }
}
