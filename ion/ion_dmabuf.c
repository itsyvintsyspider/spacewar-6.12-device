// Legacy libion API on top of dma-buf heaps; 6.12 has no /dev/ion.
// Heap selection follows suvojeet-sengupta's redwood libion patch.
#include <android/log.h>
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <linux/dma-heap.h>

#include <ion/ion.h>

#define MSM_HEAP(id) (1u << (id))
#define FLAG_CACHED (1u << 0)
#define FLAG_CP_PIXEL (1u << 19)
#define FLAG_CP_SEC_DISPLAY (1u << 25)
#define FLAG_CP_CDSP (1u << 29)
#define FLAG_SECURE (1u << 31)
#define FLAGS_CP_MASK 0x6FFE8000u

// ION heap ids of the 5.4 msm driver, reported to heap queries.
static const struct {
    const char* name;
    unsigned int id;
} kMsmHeaps[] = {
    {"qsecom_ta", 1},       {"camera", 2},     {"display", 3},        {"adsp", 4},
    {"audio_ml", 5},        {"user_contig", 6}, {"qsecom", 7},        {"audio", 8},
    {"secure_heap", 9},     {"secure_heap", 10}, {"secure_display", 11}, {"spss", 14},
    {"secure_carveout", 15}, {"system", 25},
};
#define NUM_MSM_HEAPS (sizeof(kMsmHeaps) / sizeof(kMsmHeaps[0]))

// Upstream layout; the tree's linux/ion.h predates heap queries.
struct msm_ion_heap_data {
    char name[32];
    uint32_t type;
    uint32_t heap_id;
    uint32_t reserved[3];
};

static const char* heap_for(unsigned int heap_mask, unsigned int flags) {
    if (heap_mask & MSM_HEAP(7)) return "qcom,qseecom";
    if (heap_mask & MSM_HEAP(1)) return "qcom,qseecom-ta";
    if ((heap_mask & MSM_HEAP(11)) || (flags & FLAG_CP_SEC_DISPLAY)) return "qcom,secure-display";
    if (flags & (FLAG_SECURE | FLAGS_CP_MASK)) {
        if (flags & FLAG_CP_PIXEL) return "qcom,secure-pixel";
        if (flags & FLAG_CP_CDSP) return "qcom,secure-cdsp";
        return "qcom,secure-non-pixel";
    }
    if (heap_mask & MSM_HEAP(4)) return "qcom,adsp";
    if (heap_mask & MSM_HEAP(3)) return "qcom,display";
    if (heap_mask & MSM_HEAP(5)) return "qcom,audio-ml";
    if (heap_mask & MSM_HEAP(6)) return "qcom,user-contig";
    return (flags & FLAG_CACHED) ? "qcom,system" : "qcom,system-uncached";
}

// Returns a dma-buf fd, or -errno.
static int heap_alloc(const char* name, size_t len) {
    char path[64];
    snprintf(path, sizeof(path), "/dev/dma_heap/%s", name);
    int heap = open(path, O_RDONLY | O_CLOEXEC);
    if (heap < 0) return -errno;

    struct dma_heap_allocation_data data = {
        .len = len,
        .fd_flags = O_RDWR | O_CLOEXEC,
    };
    int ret = ioctl(heap, DMA_HEAP_IOCTL_ALLOC, &data);
    int err = errno;
    close(heap);
    return ret < 0 ? -err : (int)data.fd;
}

// Callers only need a descriptor that ion_close() accepts.
int ion_open() { return open("/dev/null", O_RDONLY | O_CLOEXEC); }

int ion_close(int fd) { return close(fd); }

// Bring-up: report failed heap allocs to the kernel log.
static void kmsg_log(const char* heap, size_t len, int err) {
    char msg[96];
    int n = snprintf(msg, sizeof(msg), "<4>ion_dmabuf: pid %d heap %s len %zu err %d\n", getpid(), heap, len, err);
    __android_log_print(ANDROID_LOG_ERROR, "ion_dmabuf", "pid %d heap %s len %zu err %d", getpid(), heap, len, err);
    int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;
    if (write(fd, msg, n) < 0) {}
    close(fd);
}

int ion_alloc_fd(int fd __attribute__((unused)), size_t len, size_t align __attribute__((unused)),
                 unsigned int heap_mask, unsigned int flags, int* handle_fd) {
    if (!handle_fd) return -EINVAL;

    // Not every client may open every heap or the kernel may lack it, so end on the system heap.
    const char* const names[] = {heap_for(heap_mask, flags), "qcom,system", "system"};
    int buf = -ENODEV;
    for (size_t i = 0; i < 3 && buf < 0; i++) {
        buf = heap_alloc(names[i], len);
        if (buf < 0) kmsg_log(names[i], len, buf);  // bring-up
    }
    if (buf < 0) return buf;

    *handle_fd = buf;
    return 0;
}

int ion_is_legacy(int fd __attribute__((unused))) { return 0; }
int ion_is_using_modular_heaps(int fd __attribute__((unused))) { return 1; }

int ion_query_heap_cnt(int fd __attribute__((unused)), int* cnt) {
    if (!cnt) return -EINVAL;
    *cnt = NUM_MSM_HEAPS;
    return 0;
}

int ion_query_get_heaps(int fd __attribute__((unused)), int cnt, void* buffers) {
    struct msm_ion_heap_data* heaps = buffers;
    if (!heaps || cnt <= 0) return -EINVAL;

    for (size_t i = 0; i < NUM_MSM_HEAPS && i < (size_t)cnt; i++) {
        memset(&heaps[i], 0, sizeof(heaps[i]));
        strncpy(heaps[i].name, kMsmHeaps[i].name, sizeof(heaps[i].name) - 1);
        heaps[i].heap_id = kMsmHeaps[i].id;
    }
    return 0;
}

// dma-buf heaps need no sync call here.
int ion_sync_fd(int fd __attribute__((unused)), int handle_fd __attribute__((unused))) { return 0; }

// Handle-based calls have no dma-buf equivalent.
int ion_alloc(int fd __attribute__((unused)), size_t len __attribute__((unused)),
              size_t align __attribute__((unused)), unsigned int heap_mask __attribute__((unused)),
              unsigned int flags __attribute__((unused)),
              ion_user_handle_t* handle __attribute__((unused))) {
    return -ENOSYS;
}
int ion_free(int fd __attribute__((unused)), ion_user_handle_t handle __attribute__((unused))) {
    return -ENOSYS;
}
int ion_import(int fd __attribute__((unused)), int share_fd __attribute__((unused)),
               ion_user_handle_t* handle __attribute__((unused))) {
    return -ENOSYS;
}
int ion_share(int fd __attribute__((unused)), ion_user_handle_t handle __attribute__((unused)),
              int* share_fd __attribute__((unused))) {
    return -ENOSYS;
}
int ion_map(int fd __attribute__((unused)), ion_user_handle_t handle __attribute__((unused)),
            size_t length __attribute__((unused)), int prot __attribute__((unused)),
            int flags __attribute__((unused)), off_t offset __attribute__((unused)),
            unsigned char** ptr __attribute__((unused)), int* map_fd __attribute__((unused))) {
    return -ENOSYS;
}
