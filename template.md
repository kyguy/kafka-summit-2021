# Strimzi demo for Kafka Summit 2021

Demo for using Strimzi to manage a Kafka cluster on Kubernetes.

## Prerequisities
- Kubernetes cluster
- Namespace context set to `myproject`

## Timing
- Strimzi Basics ~13mins 
- Cruise Control ~6mins

# Demo: Strimzi Basics

Today we are going to demonstrate the Strimzi Kafka Operator for running Kafka on Kubernetes. 

```
0-overview.txt
```
In this demo, we will cover a few things like:
- How to install the Strimzi Kafka Operator.
- How to deploy and manage a Kafka cluster.

## Cluster Deployment

Let's start by deploying the Strimzi Cluster Operator to Kubernetes.

```
curl -L strimzi.io/install/latest | kubectl create -f -
```

This command will download a Strimzi installation file which defines Strimzi using Kubernetes objects like:

- CustomResourceDefinitions
- ClusterRoles
- ConfigMaps
- Deployments
- ...

and then will create these objects in Kubernetes.

We can see the CustomResourceDefinitions installed here

```
kubectl get crds
```

These will allow us to create Strimzi objects like:
- `Kafka` objects for creating Kafka clusters
- `KafkaTopic` objects for creating Kafka topics
- `KafkaUser` objects for creating Kafka users
-  ...

Let's check to see if our Strimzi Cluster Operator deployment is complete.
```
kubectl get pods -w
```

Now that the Cluster Operator is ready, we can deploy a Kafka cluster by creating a `Kafka` resource in Kuberentes like this: 
```
kubectl apply -f examples/kafka.yaml
```

Let's take a closer looks at the `Kafka` resource description 
```
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    version: 2.7.0
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: tls
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      log.message.format.version: "2.7"
      inter.broker.protocol.version: "2.7"
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: 1Gi
        deleteClaim: false
    authorization:
      type: simple
  zookeeper:
    replicas: 1
    storage:
      type: persistent-claim
      size: 1Gi
      deleteClaim: false
```

We define a Kafka cluster that 
- Has the name "my-cluster"
- Runs Apache Kafka broker version 2.7.0, note that we could have specified any other Strimzi supported Kafka versions as well
- Has one Kafka broker instance
- Has one Zookeeper instance
- Has the following Apache Kafka broker configuration.
- Exposes secure and insecure bootstrap addresses for accessing the cluster, we could have also specifed a external listener here for reaching the cluster outside Kuberentes, via nodeport, loadbalancer, or ingress.
- Uses persistent JBOD storage
- Enforces user authorization

The customizations listed here are NOT exhaustive, we can also add other configurations for things like 
- metrics
- security
- and other components!

```
1-single-broker-cluster.txt
```

Kubernetes will use this description to create a `Kafka` resource object. 
The Strimzi Cluster Operator will then create a Kafka cluster based on that description of that `Kafka` resource.
 
We can think of the `Kafka` resource as a blueprint and the operator as a builder.

Here we can see the Cluster Operator has created a single-node Kafka cluster:
```
kubectl get pods
``` 

With this cluster, there are a few things Strimzi gives us for free out of the box:
- **Security**: All communication within the cluster is encryted and authenticated by default.
- **Automated configuration management**: When we update the Kafka resource, the changes are automatically applied to all of the brokers in the cluster.

## Managing the Cluster

Just as we can manage Kafka clusters using the Strimzi _Cluster_ Operator, we can manage other Kafka components using the Strimzi _Entity_ Operator. Components like:
- Kafka topics
- Kafka users

We can deploy the Entity Operator by editing our `Kafka` resource in the following manner:

```
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
  ...
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

Notice the Entity Operator comprises of two operators:
- An operator for managing Kafka Topics
- An operator for managing Kafka Users

```
2-entity-operator.txt
```

The Cluster Operator will notice these changes in the `Kafka` resource and deploy the Entity Operator alongside our Kafka cluster.

### Kafka topics

Now that we have the Entity Operator up and running, let's create a Kafka topic.

Here we pass Kubernetes a description of our desired `KafkaTopic` resource

```
kubectl apply -f examples/kafka-topic.yaml
```

Let's look at the `KafkaTopic` resource we just passed our Operator
```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 7200000
    segment.bytes: 1073741824
```

As we can see in the description in the `KafkaTopic` resource, we describe a Kafka Topic that
- Contains 3 partitions
- Contains 1 replicas per partition
- Has the following Apache Kafka topic configurations

```
3-topic-resource.txt
```

Just like our `Kafka` resource, our `KafkaTopic` resource will used as a model by the Operator to create the object which it represents, a Kafka topic.

We can also us the Kubernetes CLI to interact with the resources.
For example to view our Kafka topics we can run:
```
kubectl get KafkaTopic
```

To update our Kafka topics we can run:

```
kubectl edit KafkaTopic my-topic
```

### Kafka users

Let's now create a Kafka user that can use this topic.

Since the Entity Operator is already running, all we need to do is pass a description of a `KafkaUser` resource to Kubernetes:

```
kubectl apply -f examples/kafka-user.yaml
```

Let's look at the description of the `KafkaUser` resource we just passed our Operator

```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-user
  labels:
    strimzi.io/cluster: my-cluster
spec:
  authentication:
    type: tls
  authorization:
    type: simple
    acls:
      # Example consumer Acls for topic my-topic using consumer group my-group
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Read
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Describe
        host: "*"
      - resource:
          type: group
          name: java-kafka-consumer
          patternType: literal
        operation: Read
        host: "*"
      # Example Producer Acls for topic my-topic
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Write
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Create
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Describe
        host: "*"
  quotas:
    producerByteRate: 1048576
    consumerByteRate: 2097152
    requestPercentage: 55
```
Here in our KafkaUser resource, we focus on a few things:
- **Authentication**:  So our Kafka user will be recognized by the Kafka cluster, here we use TLS client authentication.
- **Authorization**: So our Kafka user will have privledges to interact with topics, here we defined Access Control Lists (ACLs) for reading and writing to our topic.
- **User Quotas**: So we can limit how much our user can can read and write to brokers, here we limit the byte rate of producing and consuming to and from a broker, as well as the CPU utilization limit as a percentage of time used by the client group.


```
4-user-resource.txt
```

Our Operator will now create a Kafka user based on that description

```
kubectl get KafkaUsers
```

The User Operator has now create an authenticated Kafka user that is authorized to read and write to the topic which we have created in our Kafka broker.

## Reading and writing messages to the cluster

Now that we have our Kafka topic and Kafka user set up we can start reading and writing messages to our Kafka cluster:

Let's deploy some simple producer and consumer apps.

```
kubectl apply -f examples/producer-consumer-apps.yaml
```

Looking at the deployment 
```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: java-kafka-producer
  name: java-kafka-producer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: java-kafka-producer
  template:
    metadata:
      labels:
        app: java-kafka-producer
    spec:
      containers:
      - name: java-kafka-producer
        image: quay.io/strimzi-examples/java-kafka-producer:latest
        env:
          - name: CA_CRT
            valueFrom:
              secretKeyRef:
                name: my-cluster-cluster-ca-cert
                key: ca.crt
          - name: USER_CRT
            valueFrom:
              secretKeyRef:
                name: my-user
                key: user.crt
          - name: USER_KEY
            valueFrom:
              secretKeyRef:
                name: my-user
                key: user.key
          - name: BOOTSTRAP_SERVERS
            value: my-cluster-kafka-bootstrap:9093
          - name: TOPIC
            value: my-topic
          - name: DELAY_MS
            value: "1000"
          - name: LOG_LEVEL
            value: "INFO"
          - name: MESSAGE_COUNT
            value: "1000000"
...
```

As we can see:
- We point our clients to use the secure bootstrap address of our cluster on port 9093 which only allows authenticated traffic.
- We point our clients to use the `my-user` secret created by the User Operator which tie the clients to our Kafka user. 

Let's look at the messages moving through our Kafka broker

(Split window pane left)

```
kubectl logs java-kafka-producer -f
```

(Split window pane right)

```
kubectl logs java-kafka-consumer -f
```

We can see messaged being written to our Kafka broker on the left and read from the Kafka broker on the right.

**NOTE** No other client will be able to read or write to our topic using the secure bootstrap address without being tied to our Kafka user

So if we were to deploy a userless Kafka consumer

```
kubectl apply -f examples/unauthenticated-consumer.yaml
```
Like this:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: unauthenticated-kafka-consumer
  name: unauthenticated-kafka-consumer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: unauthenticated-kafka-consumer
  template:
    metadata:
      labels:
        app: unauthenticated-kafka-consumer
    spec:
      containers:
      - name: unauthenticated-kafka-consumer
        image: quay.io/strimzi-examples/java-kafka-consumer:latest
        env:
          # Notice how there are no secrets here linking our consumer with our Kafka user
          - name: BOOTSTRAP_SERVERS
            value: my-cluster-kafka-bootstrap:9093
          - name: TOPIC
            value: my-topic
          - name: GROUP_ID
            value: java-kafka-consumer
          - name: LOG_LEVEL
            value: "INFO"
          - name: MESSAGE_COUNT
            value: "1000000"
```
we see that it will not be able to read any messages

```
kubectl logs unauthenticated-kafka-consumer -f
```

That covers the Strimzi basics, as you have seen, using Strimzi Operators and Custom Resources we can easily deploy and manage:

- Kafka clusters
- Kafka topics
- Kafka users
- ...

in Kubernetes. 

# Demo: Cruise Control

In this demo, we will show how to balance your Kafka cluster using Strimzi Cruise Control integration.

```
7-rebalance-resource.txt
```

## Scaling

```
1-single-broker-cluster.txt
```

So far, all of our previous demos have depended on a single Kafka broker:

This raises concerns with:
- performance
- fault tolerance

We can see all of our topics' partitions are piled up on one broker here:

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server localhost:9092
```

Let's scale our cluster by adding more Kafka brokers. 

We can do this by updating our `Kafka` resource like this:
```
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    ...
    replicas: 3
    ...
```

```
5-scaled.txt
```
Just like every other change to our cluster, all we need to do is update the description of our `kafka` resource and the Cluster Operator will do the rest.

**WAIT** Let's wait for the cluster to be scaled.

We can see that our cluster now has three brokers, but all of our partitions are still piled up on broker 0!

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server my-cluster-kafka-bootstrap:9092
```

We need to redistribute these partitions to balance our cluster out.

## Cluster balancing

To balance our partitions across our brokers we can use Cruise Control, an opensource project for balancing workloads across Kafka brokers.

We can deploy Cruise Control in a similar fashion to how we deployed other components like the Entity Operator, through the `Kafka` custom resource:
```
kind: Kafka
metadata:
  name: my-cluster
spec:
  ...  
  kafka:
  ...
  cruiseControl: {}
```

```
6-cruise-control.txt
```

The Cluster Operator will notice these changes in the `Kafka` resource and deploy Cruise Control alongside our Kafka cluster.

**WAIT** Let's wait for Cruise Control to be deployed.

We can see Cruise Control deployed here
```
kubectl get pods
```

Now we need a way of interacting with the Cruise Control.

Luckily, just like for all other Kafka components, Strimzi provides a way of interacting with the Cruise Control API using the Kubernetes CLI, through `KafkaRebalance` resources.

We can create a `KafkaRebalance` resource like this:
```
kubectl apply -f examples/kafka-rebalance.yaml
```
This will serve as our medium to Cruise Control for preforming a partition rebalance.

Let's take a closer look at the `KafkaRebalance` resource:
```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaRebalance
metadata:
  name: my-rebalance
  labels:
    strimzi.io/cluster: my-cluster
spec:
  goals:
    - RackAwareGoal
    - ReplicaCapacityGoal
    - DiskCapacityGoal
    - NetworkInboundCapacityGoal
    - NetworkOutboundCapacityGoal
    - CpuCapacityGoal
    - ReplicaDistributionGoal
    - DiskUsageDistributionGoal
    - NetworkInboundUsageDistributionGoal
    - NetworkOutboundUsageDistributionGoal
    - TopicReplicaDistributionGoal
    - LeaderReplicaDistributionGoal
    - LeaderBytesInDistributionGoal    
```

The purpose of creating a `KafkaRebalance` resource is for creating **optimization proposals** and executing parition rebalances based on that **optimization proposals**.

An **optimization proposal** is a summary of proposed parition movements that would produce a more balanced Kafka cluster.

Here we pass Cruise Control a list of what priorities or goals to focus on when calculating an *optimization proposal*

For example the:

- CPU Capacity Goal

ensures the the generated proposal would keep CPU utilization for any broker in our cluster under a given threshold.

```
7-rebalance-resource.txt
```

Now that the `KafkaRebalance` resource has been created, it will be used by the Cluster Operator to request an *optimization proposal* from the Cruise Control.

Once received, the Cluster Operator will subsequently update the `KafkaRebalance` resource with the details of the *optimization proposal* for review.

We can look at the details of our optimization proposal like this
```
kubectl describe kafkarebalance my-rebalance
```

```
Status:
  Conditions:
    Last Transition Time:  2021-05-06T21:56:27.023127Z
    Status:                True
    Type:                  ProposalReady
  Observed Generation:     1
  Optimization Result:
    Data To Move MB:  0
    Excluded Brokers For Leadership:
    Excluded Brokers For Replica Move:
    Excluded Topics:
    Intra Broker Data To Move MB:         0
    Monitored Partitions Percentage:      100
    Num Intra Broker Replica Movements:   0
    Num Leader Movements:                 8
    Num Replica Movements:                90
    On Demand Balancedness Score After:   86.5211909515508
    On Demand Balancedness Score Before:  78.70730590478658
    Provision Recommendation:             
    Provision Status:                     RIGHT_SIZED
    Recent Windows:                       1
  Session Id:                             50c4ee47-aae3-4ca4-ac49-fffdcecf5834
Events:                                   <none>
```

**WAIT** Let's wait for the optimization proposal to be ready.

Once the proposal is ready and looks good, we can execute the rebalance based on that proposal, by annotating the `KafkaRebalance` resource like this:

```
kubectl annotate kafkarebalance my-rebalance strimzi.io/rebalance=approve
```

Now Cruise Control will execute a partition rebalance amongst the brokers

We can get the status of the rebalance by looking at the resource like this:

```
kubectl describe kafkarebalance my-rebalance
```

**WAIT** Let's wait for the rebalance to complete.

Once complete, we can look and see the partitions spread amongst all of the brokers.

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server my-cluster-kafka-bootstrap:9092
```
```
Topic: __consumer_offsets	Partition: 0	Leader: 0	Replicas: 0	Isr: 0
Topic: __consumer_offsets	Partition: 1	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 2	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 3	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 4	Leader: 2	Replicas: 2	Isr: 2
Topic: __consumer_offsets	Partition: 5	Leader: 2	Replicas: 2	Isr: 2
```

That is the end of the demo, as you can see, using Strimzi Operators and custom resources we can balance our Kafka clusters in Kubernetes.

# Demo: Cruise Control (Abridged)

In this demo, we will show how to balance your Kafka cluster using Strimzi Cruise Control integration.

```
6-cruise-control.txt
```

## Cruise Control

To save time, I have already scaled our cluster to 3 Kafka brokers and deployed Cruise Control by editing the `Kafka` resource like this:

```
kubectl edit kafka my-cluster
```

These changes we read by the cluster operator and then applyed to our cluster.

The problem is that even after scaling, we can see all of our topics' partitions are still piled up on one broker here:

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server localhost:9092
```

We need to redistribute these partitions to balance our cluster out.

Cruise Control is an opensource project for balancing workloads across Kafka brokers.

Since Cruise Control has already been deployed, all we need now is a way of interacting with the Cruise Control.

Luckily, just like for all other Kafka components, Strimzi provides a way of interacting with the Cruise Control API using the Kubernetes CLI, through `KafkaRebalance` resources.

We can create a `KafkaRebalance` resource like this:
```
kubectl apply -f examples/kafka-rebalance.yaml
```
This will serve as our medium to Cruise Control for preforming a partition rebalance.

Let's take a closer look at the `KafkaRebalance` resource:
```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaRebalance
metadata:
  name: my-rebalance
  labels:
    strimzi.io/cluster: my-cluster
spec:
  goals:
    - RackAwareGoal
    - ReplicaCapacityGoal
    - DiskCapacityGoal
    - NetworkInboundCapacityGoal
    - NetworkOutboundCapacityGoal
    - CpuCapacityGoal
    - ReplicaDistributionGoal
    - DiskUsageDistributionGoal
    - NetworkInboundUsageDistributionGoal
    - NetworkOutboundUsageDistributionGoal
    - TopicReplicaDistributionGoal
    - LeaderReplicaDistributionGoal
    - LeaderBytesInDistributionGoal    
```

The purpose of creating a `KafkaRebalance` resource is for creating **optimization proposals** and executing partition rebalances based on that **optimization proposals**.

An **optimization proposal** is a summary of proposed parition movements that would produce a more balanced Kafka cluster.

Here we pass Cruise Control a list of what priorities or goals to focus on when calculating an *optimization proposal*

For example the:

- CPU Capacity Goal

ensures the the generated proposal would keep CPU utilization for any broker in our cluster under a given threshold.

```
7-rebalance-resource.txt
```

Now that the `KafkaRebalance` resource has been created, it will be used by the Cluster Operator to request an *optimization proposal* from the Cruise Control.

Once received, the Cluster Operator will subsequently update the `KafkaRebalance` resource with the details of the *optimization proposal* for review.

We can look at the details of our optimization proposal like this
```
kubectl describe kafkarebalance my-rebalance
```

```
Status:
  Conditions:
    Last Transition Time:  2021-05-06T21:56:27.023127Z
    Status:                True
    Type:                  ProposalReady
  Observed Generation:     1
  Optimization Result:
    Data To Move MB:  0
    Excluded Brokers For Leadership:
    Excluded Brokers For Replica Move:
    Excluded Topics:
    Intra Broker Data To Move MB:         0
    Monitored Partitions Percentage:      100
    Num Intra Broker Replica Movements:   0
    Num Leader Movements:                 8
    Num Replica Movements:                90
    On Demand Balancedness Score After:   86.5211909515508
    On Demand Balancedness Score Before:  78.70730590478658
    Provision Recommendation:             
    Provision Status:                     RIGHT_SIZED
    Recent Windows:                       1
  Session Id:                             50c4ee47-aae3-4ca4-ac49-fffdcecf5834
Events:                                   <none>
```

**WAIT** Let's wait for the optimization proposal to be ready.

Once the proposal is ready and looks good, we can execute the rebalance based on that proposal, by annotating the `KafkaRebalance` resource like this:

```
kubectl annotate kafkarebalance my-rebalance strimzi.io/rebalance=approve
```

Now Cruise Control will execute a partition rebalance amongst the brokers

We can get the status of the rebalance by looking at the resource like this:

```
kubectl describe kafkarebalance my-rebalance
```

**WAIT** Let's wait for the rebalance to complete.

Once complete, we can look and see the partitions spread amongst all of the brokers.

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server my-cluster-kafka-bootstrap:9092
```
```
Topic: __consumer_offsets	Partition: 0	Leader: 0	Replicas: 0	Isr: 0
Topic: __consumer_offsets	Partition: 1	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 2	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 3	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 4	Leader: 2	Replicas: 2	Isr: 2
Topic: __consumer_offsets	Partition: 5	Leader: 2	Replicas: 2	Isr: 2
```

That is the end of the demo, as you can see, using Strimzi Operators and custom resources we can balance our Kafka clusters in Kubernetes.
