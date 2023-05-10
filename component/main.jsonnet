// main template for eventrouter
local com = import 'lib/commodore.libjsonnet';
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

local clusterrole = kube.ClusterRole('syn-eventrouter') {
  rules: [
    { apiGroups: [ '*' ], resources: [ 'events' ], verbs: [ 'get', 'watch', 'list' ] },
  ],
};

local clusterrolebinding = kube.ClusterRoleBinding('syn-eventrouter') {
  roleRef_: clusterrole,
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
            image: params.images.eventrouter.registry + '/' + params.images.eventrouter.image + ':' + params.images.eventrouter.tag,
            resources: params.resources.eventrouter,
            volumeMounts: [
              {
                name: 'config-volume',
                mountPath: '/etc/eventrouter',
              },
            ],
          },
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
      } + com.makeMergeable(params.spec),
    },
  },
};


// Define outputs below
{
  '00_namespace': kube.Namespace(params.namespace),
  '10_eventrouter': [ serviceaccount, clusterrole, clusterrolebinding, configmap, deployment ],
}
