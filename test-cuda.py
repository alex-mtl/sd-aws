import torch

if torch.cuda.is_available():
    device_count = torch.cuda.device_count()
    device_name = torch.cuda.get_device_name(0)
    memory_allocated = torch.cuda.memory_allocated(0)
    memory_cached = torch.cuda.memory_cached(0)

    print(f"Number of GPUs: {device_count}")
    print(f"GPU Device Name: {device_name}")
    print(f"GPU Memory Allocated: {memory_allocated / 1024 ** 3:.2f} GB")
    print(f"GPU Memory Cached: {memory_cached / 1024 ** 3:.2f} GB")
else:
    print("GPU is not available.")

