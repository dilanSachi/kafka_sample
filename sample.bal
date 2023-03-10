import ballerinax/kafka;
import ballerina/log;
import ballerina/os;
import ballerina/time;

// configurable string groupId = "order-consumers-" + time:utcNow().toString();
// configurable string orders = "orders";
// configurable string paymentSuccessOrders = "payment-success-orders";
// configurable decimal pollingInterval = 1;
// configurable string kafkaEndpoint = ?;
// configurable string username = ?;
// configurable string password = ?;


string groupId = "order-consumers-" + time:utcNow().toString();
string orders = "orders";
string paymentSuccessOrders = "payment-success-orders";
decimal pollingInterval = 1;
string kafkaEndpoint = os:getEnv("endpoint");
string username = os:getEnv("username");
string password = os:getEnv("password");


//configurable string kafkaEndpoint = "2.tcp.ngrok.io:14890";

// public type Order readonly & record {|
//     int id;
//     string desc;
//     PaymentStatus paymentStatus;
// |};

//{"ordertime": 1497014222380,"orderid": 18,"itemid": "Item_184","paymentStatus": "SUCCESS","address": {"city": "Mountain View","state": "CA","zipcode": 94041}}

public enum PaymentStatus {
    SUCCESS,
    FAIL
}

public type Order record {
    string itemid;
    boolean isValid=true;
    record {
        int zipcode;
        string city;
        string state;
    } address;
    int orderid;
    decimal ordertime;
    PaymentStatus paymentStatus?;
};

// {
// 	"ordertime": 1497014222380,
// 	"orderid": 18,
// 	"itemid": "Item_184",
//     "paymentStatus": "SUCCESS",
// 	"address": {
// 		"city": "Mountain View",
// 		"state": "CA",
// 		"zipcode": 94041
// 	}
// }

// kafka:ConsumerConfiguration consumerConfigs = {
//     groupId: "group-id",
//     topics: ["topic_order"],
//     pollingInterval: 1,
//     autoCommit: false,
//     securityProtocol: kafka:PROTOCOL_SASL_SSL,
//     auth: {username: "xxx", password: "xx"}
// };

listener kafka:Listener kafkaListener = new (kafkaEndpoint, consumerConfigs);

final kafka:ConsumerConfiguration consumerConfigs = {
    groupId: groupId,
    topics: [orders],
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    auth: {username, password},
    securityProtocol: kafka:PROTOCOL_SASL_SSL,
    pollingInterval
};

final kafka:ProducerConfiguration producerConfigs ={
    auth: {username, password},
    securityProtocol: kafka:PROTOCOL_SASL_SSL
};

service on kafkaListener {
    private final kafka:Producer orderProducer;

    function init() returns error? {
        self.orderProducer = check new (kafkaEndpoint,producerConfigs);
    }

    remote function onConsumerRecord(Order[] orders) returns error? {
        log:printInfo("Received orders: " + orders.toString());
        check from Order 'order in orders
            where 'order.paymentStatus == SUCCESS
            do {
                log:printInfo("SUCCESS orders: " + orders.toString());
                check self.orderProducer->send({
                    topic: paymentSuccessOrders,
                    value: 'order
                });
            };
    }
}
