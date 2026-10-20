"""Create missing recordings, or refresh existing recordings when requested."""
function ensure_recording(path, warmup, record; skip_existing_cast=true, runner=run)
    if !isfile(path) || !skip_existing_cast
        # Warm up first so package installation/precompilation is not recorded.
        runner(warmup)
        runner(record)
    end
    isfile(path) || error("Recording was not generated: $path")
    return nothing
end
