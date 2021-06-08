The example cluster as shown in this example consists of 3 instances, each of which store it's data on an automatic provisioned AWS EBS volume.
The kafka image itself creates a new broker-id when first booted up. For each consecutive boot up it reuses the broker-id found on the peristent volume.

