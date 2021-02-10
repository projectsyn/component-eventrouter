// main template for eventrouter
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.eventrouter;

local serviceaccount = kube.ServiceAccount('eventrouter') {
  metadata+: {
    namespace: params.namespace,
  },
};

local clusterrole = kube.ClusterRole('eventrouter') {
  rules: [
    { apiGroups: [ '*' ], resources: [ 'events' ], verbs: [ 'get', 'watch', 'list' ] },
  ],
};

local clusterrolebinding = kube.ClusterRoleBinding('eventrouter') {
  roleRef+: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'eventrouter',
  },
  subjects_: [ serviceaccount ],
};

local configmap = kube.ConfigMap('eventrouter') {
  metadata+: {
    namespace: params.namespace,
  },
  data: {
    'config.json': '{ "sink": "stdout" }',
  },
};

local deployment = kube.Deployment('eventrouter') {
  metadata+: {
    namespace: params.namespace,
    labels: {
      'app.kubernetes.io/name': 'eventrouter',
      'app.kubernetes.io/managed-by': 'syn',
    },
  },
  spec+: {
    template+: {
      spec+: {
        containers_+: {
          'kube-eventrouter': kube.Container('kube-eventrouter') {
            image: params.images.eventrouter.image + ':' + params.images.eventrouter.tag,
            imagePullPolicy: 'Always',
            volumeMounts: [
              {
                name: 'config-volume',
                mountPath: '/etc/eventrouter',
              },
            ],
          },
        },
        securityContext: {
          runAsUser: 10001,
        },
        serviceAccountName: serviceaccount.metadata.name,
        volumes: [
          {
            name: 'config-volume',
            configMap: {
              name: configmap.metadata.name,
            },
          },
        ],
      },
    },
  },
};


// Define outputs below
{
  '00_namespace': kube.Namespace(params.namespace),
  '10_eventrouter': [ serviceaccount, clusterrole, clusterrolebinding, configmap, deployment ],
}
