# Generated by Django 3.2.18 on 2023-03-27 12:39

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('oauth_dispatch', '0012_noop_migration_to_test_rollback'),
    ]

    operations = [
        # CREATE INDEX is a non-blocking operation in MySql 5.6 and above
        # Adding as raw SQL because we don't have access to the underlying model.
        #
        # WARNING:
        # This migration may cause problems in the future if django-oauth-toolkit ever decides to update the AccessToken
        # model with the same index name. However, if they do it using the ORM and autogenerated migrations it will
        # add a hash onto the index name so we should be safe
        migrations.RunSQL(
            sql='''CREATE INDEX oauth2_provider_accesstoken_expires ON oauth2_provider_accesstoken (expires), ALGORITHM=INPLACE, LOCK=NONE;''',
            reverse_sql='DROP INDEX oauth2_provider_accesstoken_expires ON oauth2_provider_accesstoken;',
        ),
    ]

