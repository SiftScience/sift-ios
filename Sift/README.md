Overview of the Sift module

The "unit" of data is an `SFEvent` object.  You create it and send it to
the shared `Sift` object.  The `Sift` object will append that `SFEvent`
to the `SFQueue` you specify.  When the events of a `SFQueue` is ready
for uploading (as specified in `SFQueueConfig`), that `SFQueue` will
notify `SFUploader`, which will then collect events from all queues of
which events are ready for uploading, and upload events in one batch.

To have better batching results, you should create queues based on your
batching requirements rather than solely based on event types.  (There
is a default queue, which might be all you need.)

```
  +---------+
  | SFEvent |
  +---------+                            _   _
       |                                ( `   )_
       | 0. Send event to Sift         (   )    `)  )
       |                            (_   (_ .     _)  _)
       v
    +------+                            ^
    | Sift |                            |
    +------+                            | 4. Upload events to Sift
       |                                |
       |                      +------------+
       |                      | SFUploader |
       |                      +------------+
       | 1. Appene event to      ^    |
       |    SFQueue              |    |
       |                         |    |
       |       2. Request upload |    |
       |          when ready     |    |
       |                         |    |
       |    +-----------------+  |    | 3. Collect events from
       |    | SFQueue         |  |    |    all ready queues
       |    |   SFQueueConfig |<-|----+
       |    +-----------------+  |    |
       |                         |    |
       |    +-----------------+  |    |
       +--->| SFQueue         |--+    |
            |   SFQueueConfig |<------+
            +-----------------+       |
                                      |
            +-----------------+       |
            | SFQueue         |       |
            |   SFQueueConfig |<------+
            +-----------------+
```
