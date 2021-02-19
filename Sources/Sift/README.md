Overview of the Sift module

The "unit" of data is an `SiftEvent` object.  You create it and send it to
the shared `Sift` object.  The `Sift` object will append that `SiftEvent`
to the `SiftQueue` you specify.  When the events of a `SiftQueue` is ready
for uploading (as specified in `SiftQueueConfig`), that `SiftQueue` will
notify `SiftUploader`, which will then collect events from all queues of
which events are ready for uploading, and upload events in one batch.

To have better batching results, you should create queues based on your
batching requirements rather than solely based on event types.  (There
is a default queue, which might be all you need.)

```
  +-----------+
  | SiftEvent |
  +-----------+                            _   _
       |                                ( `   )_
       | 0. Send event to Sift         (   )    `)  )
       |                            (_   (_ .     _)  _)
       v
    +------+                            ^
    | Sift |                            |
    +------+                            | 4. Upload events to Sift
       |                                |
       |                      +--------------+
       |                      | SiftUploader |
       |                      +--------------+
       | 1. Append event to      ^    |
       |    SiftQueue            |    |
       |                         |    |
       |       2. Request upload |    |
       |          when ready     |    |
       |                         |    |
       |    +-----------------+  |    | 3. Collect events from
       |    | SiftQueue       |  |    |    all ready queues
       |    | SiftQueueConfig |<-|----+
       |    +-----------------+  |    |
       |                         |    |
       |    +-----------------+  |    |
       +--->| SiftQueue       |--+    |
            | SiftQueueConfig |<------+
            +-----------------+       |
                                      |
            +-----------------+       |
            | SiftQueue       |       |
            | SiftQueueConfig |<------+
            +-----------------+
```
