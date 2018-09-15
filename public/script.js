var app = new Vue({
    el: "#app",
    data: {
        last_deploy_timestamp: "2018-08-01 00:00:01",
        href_prefix: "http://",
        href_postfix: ".test.bowdoinorient.co",
        ajax_prefix: "http://deploy.bowdoinorient.co/",
        devenv_form_visible: false,
        new_devenv_subdomain: "",
        devenvs: [
            {
                subdomain: 'master',
                last_updated: "2018-08-01 00:00:01",
                more_text: "Continuously pulls from the master branch.",
            }
        ],
        new_devenv: false,
        rsync_code: "",
        scp_code: "",
        mysql_username: "",
        mysql_password: ""
    },
    filters: {
        reldate: function(timestamp) {
            console.log(timestamp)
            return moment(timestamp).fromNow()
        }
    },
    methods: {
        deploy_master: function() {
            axios.get(this.ajax_prefix + 'deploy_master')
        },

        update_master: function() {
            axios.get(this.ajax_prefix + 'update_master')
        },

        get_devenvs: function() {
        },

        new_devenv_confirm: function(subdomain, other_info) {
            this.devenv_form_visible = false
            var subdomain = this.new_devenv_subdomain
            this.new_devenv_subdomain = ""
            axios.get(this.ajax_prefix + 'new_devenv?subdomain=' + subdomain + '&creator=jlittle').then(function(res) {
                app.devenvs.push(res.data)

                app.scp_code = "scp -r deploy.bowdoinorient.co:/var/www/wordpress/" + res.data["subdomain"] + " {local location}"
                app.rsync_code = "rsync -ar --delete-before {local location} james@159.89.231.230:/var/www/wordpress/" + res.data["subdomain"]
                app.mysql_username = res.data["subdomain"]
                app.mysql_password = res.data["sql_password"]
                app.new_devenv = true
            }).catch(function(err) {
                alert(err)
            })
        },

        info_env: function(sd) {
            console.log(sd)
            devenv = this.devenvs.filter(function(env) {
                return env.subdomain == sd
            })[0]

            console.log(devenv)

            app.scp_code = "scp -r james@deploy.bowdoinorient.co:/var/www/wordpress/" + sd + " {local location}"
            app.rsync_code = "rsync -ar --delete-before {local location} james@deploy.bowdoinorient.co:/var/www/wordpress/" + sd
            app.mysql_username = sd
            app.mysql_password = devenv["sql_password"]
            app.new_devenv = true
        },

        delete_env: function(sd) {
            if(sd == "master") {
                return
            }

            this.devenvs = this.devenvs.filter(function(el) {
                return el.subdomain != sd
            });

            axios.get(this.ajax_prefix + 'delete_devenv?subdomain=' + sd)
        }
    },

    created: function() {
        axios.get(this.ajax_prefix + 'devenvs').then(function(res) {
            console.log(res.data)
            app.devenvs = app.devenvs.concat(res.data)
        })
        .catch(function(err) {
            alert(err)
        });
    }
});


