export const IDL = {
  address: 'CyD2G9sdMQnGm2GKnQJcEvMKQYdGiLB4mqurK1ustrHL',
  metadata: {
    name: 'biotracer',
    version: '0.1.0',
    spec: '0.1.0',
    description: 'BioTracer medicine batch tracking',
  },
  instructions: [
    {
      name: 'initialize_batch',
      discriminator: [126, 44, 205, 90, 220, 105, 105, 193],
      accounts: [
        { name: 'batch_account', writable: true },
        { name: 'biotracer', writable: true, signer: true },
        { name: 'node', signer: true },
        { name: 'system_program', address: '11111111111111111111111111111111' },
      ],
      args: [{ name: 'batch_id', type: 'u32' }],
    },
    {
      name: 'update_status',
      discriminator: [147, 215, 74, 174, 55, 191, 42, 0],
      accounts: [
        { name: 'batch_account', writable: true },
        { name: 'biotracer', writable: true, signer: true },
        { name: 'node', signer: true },
      ],
      args: [
        { name: 'new_status', type: 'u8' },
        { name: 'action', type: 'u8' },
      ],
    },
  ],
  accounts: [
    {
      name: 'MedicineBatch',
      discriminator: [99, 128, 119, 187, 209, 100, 213, 118],
    },
  ],
  events: [
    {
      name: 'TraceEvent',
      discriminator: [83, 247, 97, 132, 226, 82, 75, 118],
    },
  ],
  errors: [
    {
      code: 6000,
      name: 'InvalidStatus',
      msg: 'Invalid status. Must be 0 (Indústria), 1 (Transporte), 2 (Hospital), 3 (Recusado), or 4 (Descartado)',
    },
    { code: 6001, name: 'InvalidStatusTransition', msg: 'Status can only progress forward.' },
  ],
  types: [
    {
      name: 'MedicineBatch',
      type: {
        kind: 'struct',
        fields: [
          { name: 'batch_id', type: 'u32' },
          { name: 'status', type: 'u8' },
          { name: 'biotracer', type: 'pubkey' },
        ],
      },
    },
    {
      name: 'TraceEvent',
      type: {
        kind: 'struct',
        fields: [
          { name: 'batch_id', type: 'u32' },
          { name: 'status', type: 'u8' },
          { name: 'action', type: 'u8' },
          { name: 'node', type: 'pubkey' },
          { name: 'timestamp', type: 'i64' },
        ],
      },
    },
  ],
} as const;

export type MedicineBatch = typeof IDL;
